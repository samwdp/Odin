//+private
//+build darwin
package sync2

import "core:c"
import "core:time"

foreign import System "System.framework"

foreign System {
	__ulock_wait  :: proc "c" (operation: u32, addr: rawptr, value: u64, timeout_ms: u32) -> c.int ---
	__ulock_wait2 :: proc "c" (operation: u32, addr: rawptr, value: u64, timeout_ns: u64, value2: u64) -> c.int ---
	__ulock_wake  :: proc "c" (operation: u32, addr: rawptr, wake_value: u64) -> c.int ---
}


UL_COMPARE_AND_WAIT :: 1
ULF_WAKE_ALL        :: 0x00000100
ULF_NO_ERRNO        :: 0x01000000

ENOENT    :: -2
EINTR     :: -4
EFAULT    :: -14
ETIMEDOUT :: -60

_futex_wait :: proc(f: ^Futex, expected: u32) -> Futex_Error {
	return _futex_wait_with_timeout(f, expected, 0)
}

_futex_wait_with_timeout :: proc(f: ^Futex, expected: u32, duration: time.Duration) -> Futex_Error {
	timeout_ns := u64(duration)
	
	s := __ulock_wait2(UL_COMPARE_AND_WAIT | ULF_NO_ERRNO, f, u64(expected), timeout_ns, 0)
	if s >= 0 {
		return nil
	}
	switch s {
	case EINTR, EFAULT:
		return nil
	case ETIMEDOUT:
		return .Timed_Out
	case:
		panic("futex_wait failure")
	}
	return nil

}

_futex_wake_single :: proc(f: ^Futex) {
	loop: for {
		s := __ulock_wake(UL_COMPARE_AND_WAIT | ULF_NO_ERRNO, f, 0)
		if s >= 0 {
			return
		}
		switch s {
		case EINTR, EFAULT: 
			continue loop
		case ENOENT:
			return
		case:
			panic("futex_wake_single failure")
		}
	}
}

_futex_wake_all :: proc(f: ^Futex) {
	loop: for {
		s := __ulock_wake(UL_COMPARE_AND_WAIT | ULF_NO_ERRNO | ULF_WAKE_ALL, f, 0)
		if s >= 0 {
			return
		}
		switch s {
		case EINTR, EFAULT: 
			continue loop
		case ENOENT:
			return
		case:
			panic("futex_wake_all failure")
		}
	}
}

