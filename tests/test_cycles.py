"""Integration tests against the actual Win32 console executable (no packages).

Run: python tests/test_cycles.py [build/forth.exe]
Each case gets an isolated hidden console and a timeout, including hung loops.
"""
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import re
import subprocess
import sys
import time


class Coord(C.Structure):
    _fields_ = [("x", W.SHORT), ("y", W.SHORT)]


class Key(C.Structure):
    _fields_ = [("down", W.BOOL), ("repeat", W.WORD),
                ("vk", W.WORD), ("scan", W.WORD),
                ("char", W.WCHAR), ("control", W.DWORD)]


class Event(C.Union):
    _fields_ = [("key", Key), ("padding", C.c_byte * 16)]


class Input(C.Structure):
    _fields_ = [("type", W.WORD), ("event", Event)]


k = C.WinDLL("kernel32", use_last_error=True)
k.CreateFileW.argtypes = [W.LPCWSTR, W.DWORD, W.DWORD, C.c_void_p,
                          W.DWORD, W.DWORD, W.HANDLE]
k.CreateFileW.restype = W.HANDLE
k.ReadConsoleOutputCharacterW.argtypes = [W.HANDLE, W.LPWSTR, W.DWORD,
                                         Coord, C.POINTER(W.DWORD)]
k.WriteConsoleInputW.argtypes = [W.HANDLE, C.POINTER(Input), W.DWORD,
                                C.POINTER(W.DWORD)]
k.CloseHandle.argtypes = [W.HANDLE]


def check(ok):
    if not ok:
        raise C.WinError(C.get_last_error())


def run(exe, lines):
    startup = subprocess.STARTUPINFO()
    startup.dwFlags = subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    proc = subprocess.Popen([str(exe)], creationflags=subprocess.CREATE_NEW_CONSOLE,
                            startupinfo=startup)
    handles = []
    try:
        k.FreeConsole()
        deadline = time.monotonic() + 5
        while not k.AttachConsole(proc.pid):
            if time.monotonic() > deadline:
                raise TimeoutError("AttachConsole")
            time.sleep(.01)
        for name in ("CONIN$", "CONOUT$"):
            handle = k.CreateFileW(name, 0xC0000000, 3, None, 3, 0, None)
            check(handle != W.HANDLE(-1).value)
            handles.append(handle)
        # Disable input echo so assertions only see interpreter output.
        check(k.SetConsoleMode(W.HANDLE(handles[0]), 3))
        buf = C.create_unicode_buffer(32768)
        count = W.DWORD()

        def screen():
            check(k.ReadConsoleOutputCharacterW(handles[1], buf, len(buf)-1,
                                                Coord(0, 0), C.byref(count)))
            return buf[:count.value].replace("\x00", " ")

        def wait_prompts(n):
            end = time.monotonic() + 3
            while time.monotonic() < end:
                text = screen()
                if text.count(">> ") >= n:
                    return text
                time.sleep(.01)
            raise TimeoutError(f"Console did not return to prompt: {text.strip()}")

        text = wait_prompts(1)
        for number, line in enumerate(lines, 2):
            assert len(line) < 255
            records = (Input * (len(line) + 1))()
            for record, char in zip(records, line + "\r"):
                record.type = 1
                record.event.key = Key(True, 1, 13 if char == "\r" else 0,
                                       0, char, 0)
            check(k.WriteConsoleInputW(handles[0], records, len(records), C.byref(count)))
            text = wait_prompts(number)
        return re.sub(r"\s+", " ", text.split(">> ", 1)[1]).strip()
    finally:
        for handle in handles:
            k.CloseHandle(handle)
        k.FreeConsole()
        proc.terminate()
        proc.wait(timeout=5)


CASES = [
    ("ascending", [": t 10 0 do i 2 +loop ; t .s"], "[ 0 2 4 6 8 ] OK >>"),
    ("overshoot", [": t 10 0 do i 3 +loop ; t .s"], "[ 0 3 6 9 ] OK >>"),
    ("descending exact", [": t 0 6 do i -2 +loop ; t .s"], "[ 6 4 2 0 ] OK >>"),
    ("descending overshoot", [": t 0 5 do i -2 +loop ; t .s"], "[ 5 3 1 ] OK >>"),
    ("negative bounds", [": t -1 -7 do i 2 +loop ; t .s"], "[ -7 -5 -3 ] OK >>"),
    ("cross zero", [": t -3 3 do i -2 +loop ; t .s"], "[ 3 1 -1 -3 ] OK >>"),
    ("equal descending", [": t 3 3 do i -1 +loop ; t .s"], "[ 3 ] OK >>"),
    ("equal entry", [": t 3 3 do i exit 1 +loop ; t .s"], "[ 3 ] OK >>"),
    ("dynamic step", [": t 10 0 do i i 1 + +loop ; t .s"], "[ 0 1 3 7 ] OK >>"),
    ("zero step", ["variable n : t 0 n ! 3 0 do i n @ 1 + dup n ! 3 = if exit then 0 +loop ; t .s"], "[ 0 0 0 ] OK >>"),
    ("away from limit", [": t 0 3 do i dup 5 = if exit then 1 +loop ; t .s"], "[ 3 4 5 ] OK >>"),
    ("positive overflow", [": t 2147483647 2147483646 do i 2 +loop ; t .s"], "[ 2147483646 ] OK >>"),
    ("negative overflow", [": t -2147483648 -2147483647 do i -2 +loop ; t .s"], "[ -2147483647 ] OK >>"),
    ("wrap positive", [": t -2147483647 2147483646 do i 2 +loop ; t .s"], "[ 2147483646 -2147483648 ] OK >>"),
    ("wrap negative", [": t 2147483647 -2147483648 do i -1 +loop ; t .s"], "[ -2147483648 2147483647 ] OK >>"),
    ("min step", [": t 0 1 do i -2147483648 +loop ; t .s"], "[ 1 ] OK >>"),
    ("nested j k", [": t 2 0 do 3 1 do 0 2 do i j k -2 +loop loop loop ; t .s"], "[ 2 1 0 0 1 0 2 2 0 0 2 0 2 1 1 0 1 1 2 2 1 0 2 1 ] OK >>"),
    ("callee indices", [": ix i j + ; : t 2 0 do 4 0 do ix 2 +loop loop ; t .s"], "[ 0 2 1 3 ] OK >>"),
    ("return stack", [": t 99 >r 4 0 do i 2 +loop r> ; t .s"], "[ 0 2 99 ] OK >>"),
    ("exit cleanup", [": t 3 0 do i exit 1 +loop ; t clear i"], "Loop context error >>"),
    ("step underflow cleanup", [": t 3 0 do 1 drop +loop ; t", "i"], "Stack underflow >> Loop context error >>"),
    ("do underflow", [": t 3 do 1 +loop ; t .s"], "Stack underflow [ 3 ] >>"),
    ("ordinary loop", [": t 4 0 do i loop ; t .s"], "[ 0 1 2 3 ] OK >>"),
    ("ordinary empty", [": t 3 3 do 99 loop 0 3 do 88 loop ; t .s"], "[ ] OK >>"),
    ("control rollback", [": bad begin 1 +loop ;", ": good 4 0 do i 2 +loop ; good .s"], "Control structure error >> [ 0 2 ] OK >>"),
    ("unclosed if", [": bad 3 0 do 1 if 2 +loop ;"], "Control structure error >>"),
    ("unclosed do", [": bad 3 0 do 1 ;"], "Control structure error >>"),
    ("interpretation", ["+loop"], "Control structure error >>"),
    ("internal compile", [": bad (+loop) ;"], "Internal word >>"),
    ("internal do compile", [": bad (+do) ;"], "Internal word >>"),
    ("internal interpretation", ["(+loop)", "(+do)"], "Internal word >> Internal word >>"),
    ("basics", [": cinco 5 ; : doble dup + ; cinco doble . 10 constant diez diez . variable x 123 x ! x @ ."], "10 10 123 OK >>"),
    ("conditionals", [": t dup 0< if -1 * else 1 + then ; -5 t . 5 t ."], "5 6 OK >>"),
    ("begin loops", [": t 0 begin 1 + dup 3 = until ; : w 0 begin dup 3 < while 1 + repeat ; t . w ."], "3 3 OK >>"),
    ("again exit", [": t 0 begin 1 + dup 3 = if exit then again ; t ."], "3 OK >>"),
]


if __name__ == "__main__":
    exe = Path(sys.argv[1] if len(sys.argv) > 1 else "build/forth.exe").resolve()
    failed = 0
    for name, lines, expected in CASES:
        try:
            actual = run(exe, lines)
            assert actual == expected, f"expected {expected!r}, got {actual!r}"
            print(f"PASS {name}")
        except Exception as error:
            failed += 1
            print(f"FAIL {name}: {error}")
    # Check the public dictionary and rollback without fixing its word order.
    try:
        words = run(exe, [": bad begin 1 +loop ;", "words"]).split()
        assert "+loop" in words and "loop" in words
        assert not set(["bad", "(+do)", "(+loop)", "(do)", "(loop)"]).intersection(words)
        print("PASS dictionary visibility and rollback")
    except Exception as error:
        failed += 1
        print(f"FAIL dictionary visibility and rollback: {error}")
    print(f"{len(CASES) + 1 - failed}/{len(CASES) + 1} passed")
    sys.exit(bool(failed))
