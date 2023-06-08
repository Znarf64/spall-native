package main

import "core:intrinsics"
import "core:mem"
import "core:math/rand"
import "core:math"
import "core:fmt"
import "core:c"
import "core:strings"

trap :: proc() -> ! {
	intrinsics.trap()
}

panic :: proc(fmt_in: string, args: ..any) -> ! {
	fmt.printf(fmt_in, ..args)
	intrinsics.trap()
}
post_error :: proc(trace: ^Trace, fmt_in: string, args: ..any) {
	fmt.eprintf(fmt_in, ..args)
	fmt.eprintf("\n")
	trace.error_message = fmt.bprintf(trace.error_storage[:], fmt_in, ..args)
}

@(cold)
push_fatal :: proc(err: SpallError) -> ! {
	fmt.eprintf("Error: %v\n", err)
	trap()
	// os.exit(1)
}

rand_int :: proc(min, max: int) -> int {
    return int(rand.int31()) % (max-min) + min
}

split_u64 :: proc(x: u64) -> (u32, u32) {
	lo := u32(x)
	hi := u32(x >> 32)
	return lo, hi
}

compose_u64 :: proc(lo, hi: u32) -> (u64) {
	return u64(hi) << 32 | u64(lo)
}

rescale :: proc(val, old_min, old_max, new_min, new_max: $T) -> T {
	old_range := old_max - old_min
	new_range := new_max - new_min
	return (((val - old_min) * new_range) / old_range) + new_min
}

i_round_down :: proc(x, align: $T) -> T {
	return x - (x %% align)
}

i_round_up :: proc(x, align: $T) -> T {
	return ((x + align - 1) / align) * align
}

div_ceil :: proc(x, y: $T) -> T {
	return ((x + y) - 1) / y
}

f_round_down :: proc(x, align: $T) -> T {
	return x - math.remainder(x, align)
}

val_in_range :: proc(val, start, end: $T) -> bool {
	return val >= start && val <= end
}
range_in_range :: proc(s1, e1, s2, e2: $T) -> bool {
	return s1 <= e2 && e1 >= s2
}

pt_in_rect :: proc(pt: Vec2, box: Rect) -> bool {
	x1 := box.x
	y1 := box.y
	x2 := box.x + box.w
	y2 := box.y + box.h

	return x1 <= pt.x && pt.x <= x2 && y1 <= pt.y && pt.y <= y2
}

rect_in_rect :: proc(a, b: Rect) -> bool {
	a_left := a.x
	a_right := a.x + a.w

	a_top := a.y
	a_bottom := a.y + a.h

	b_left := b.x
	b_right := b.x + b.w

	b_top := b.y
	b_bottom := b.y + b.h

	return !(b_left > a_right || a_left > b_right || a_top > b_bottom || b_top > a_bottom)
}

ease_in :: proc(t: f32) -> f32 {
	return 1 - math.cos((t * math.PI) / 2)
}
ease_in_out :: proc(t: f32) -> f32 {
    return -(math.cos(math.PI * t) - 1) / 2;
}

ONE_MINUTE :: 1000 * 1000 * 1000 * 60
ONE_SECOND :: 1000 * 1000 * 1000
ONE_MILLI  :: 1000 * 1000
ONE_MICRO  :: 1000
ONE_NANO   :: 1

tooltip_fmt :: proc(time: f64) -> string {
	if time >= ONE_SECOND {
		cur_time := time / ONE_SECOND
		return fmt.tprintf("%.1f s ", cur_time)
	} else if time >= ONE_MILLI {
		cur_time := time / ONE_MILLI
		return fmt.tprintf("%.1f ms", cur_time)
	} else if time >= ONE_MICRO {
		cur_time := time / ONE_MICRO
		return fmt.tprintf("%.1f μs", cur_time)
	} else {
		return fmt.tprintf("%.0f ns", time)
	}
}

stat_fmt :: proc(time: f64) -> string {
	if time >= ONE_SECOND {
		cur_time := time / ONE_SECOND
		return fmt.tprintf("%.1f s ", cur_time)
	} else if time >= ONE_MILLI {
		cur_time := time / ONE_MILLI
		return fmt.tprintf("%.1f ms", cur_time)
	} else if time >= ONE_MICRO {
		cur_time := time / ONE_MICRO
		return fmt.tprintf("%.1f us", cur_time) // μs
	} else {
		return fmt.tprintf("%.1f ns", time)
	}
}

my_write_float :: proc(b: ^strings.Builder, f: f64, prec: int) -> (n: int) {
	return strings.write_float(b, f, 'f', prec, 8*size_of(f))
}

time_fmt :: proc(time: f64) -> string {
	b := strings.builder_make(context.temp_allocator)

	mins := math.floor(math.mod(time / ONE_MINUTE, 60))
	if mins > 0 && mins < 60 {
		strings.write_byte(&b, ' ')
		my_write_float(&b, mins, 0)
		strings.write_byte(&b, 'm')
	} 

	secs := math.floor(math.mod(time / ONE_SECOND, 60))
	if secs > 0 && secs < 60 {
		strings.write_byte(&b, ' ')
		my_write_float(&b, secs, 0)
		strings.write_byte(&b, 's')
	} 

	millis := math.floor(math.mod(time / ONE_MILLI, 1000))
	if millis > 0 && millis < 1000 {
		strings.write_byte(&b, ' ')
		my_write_float(&b, millis, 0)
		strings.write_string(&b, "ms")
	} 

	micros := math.floor(math.mod(time / ONE_MICRO, 1000))
	if micros > 0 && micros < 1000 {
		strings.write_byte(&b, ' ')
		my_write_float(&b, micros, 0)
		strings.write_string(&b, "μs")
	}

	nanos := math.floor(math.mod(time, 1000))
	if (nanos > 0 && nanos < 1000) || time == 0 {
		strings.write_byte(&b, ' ')
		my_write_float(&b, nanos, 0)
		strings.write_string(&b, "ns")
	}

	_, picos := math.modf(time)
	picos = math.floor(picos * 1000)
	if (picos > 0 && picos < 1000) {
		strings.write_byte(&b, ' ')
		my_write_float(&b, picos, 0)
		strings.write_string(&b, "ps")
	}

	return strings.to_string(b)
}

TimeClump :: struct {
	value: f64,
	unit: string,
	max: f64,
	digits: int,
}

measure_fmt :: proc(time: f64) -> string {
	b := strings.builder_make(context.temp_allocator)

	_, picos := math.modf(time)
	picos = math.floor(picos * 1000)

	nanos := math.floor(math.mod(time, 1000))
	micros := math.floor(math.mod(time / ONE_MICRO, 1000))
	millis := math.floor(math.mod(time / ONE_MILLI, 1000))
	secs := math.floor(math.mod(time / ONE_SECOND, 60))
	mins := math.floor(math.mod(time / ONE_MINUTE, 60))

	clumps := [?]TimeClump{
		{mins,   "m",    60, 2},
		{secs,   "s",    60, 2},
		{millis, "ms", 1000, 3},
		{micros, "μs", 1000, 3},
		{nanos,  "ns", 1000, 3},
		{picos,  "ps", 1000, 3},
	}

	for clump, idx in clumps {
		if (clump.value > 0) && (clump.value < clump.max) {
			if (strings.builder_len(b) > 0 && idx > 0) {
				strings.write_rune(&b, ' ')
			}

			digits := int(math.log10(clump.value) + 1)
			for ;digits < clump.digits; digits += 1 {
				strings.write_byte(&b, ' ')
			}

			my_write_float(&b, clump.value, 0)
			strings.write_string(&b, clump.unit)
		}
	}

	return strings.to_string(b)
}

parse_u32 :: proc(str: string) -> (val: u32, ok: bool) {
	ret : u64 = 0

	s := transmute([]u8)str
	for ch in s {
		if ch < '0' || ch > '9' || ret > u64(c.UINT32_MAX) {
			return
		}
		ret = (ret * 10) + u64(ch & 0xf)
	}
	return u32(ret), true
}

hexdigits := []u8{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' }
u64_to_hexstr :: proc(buf: []byte, val: u64) -> string {
	i := 17
	x := val

	if val == 0 {
		buf[0] = '0'
		buf[1] = 'x'
		buf[2] = '0'
		return string(buf[:3])
	}

	for ; x != 0; x /= 16 {
		buf[i] = hexdigits[x % 16]
		i -= 1
	}
	buf[i] = 'x'; i -= 1
	buf[i] = '0'
	return string(buf[i:])
}

// this *shouldn't* be called with 0-len strings. 
// The current JSON parser enforces it due to the way primitives are parsed
// We reject NaNs, Infinities, and Exponents in this house.
parse_f64 :: proc(str: string) -> (ret: f64, ok: bool) #no_bounds_check {
	sign: f64 = 1

	i := 0
	if str[0] == '-' {
		sign = -1
		i += 1

		if len(str) == 1 {
			return 0, false
		}
	}

	val: f64 = 0
	for ; i < len(str); i += 1 {
		ch := str[i]

		if ch == '.' {
			break
		}

		if ch < '0' || ch > '9' {
			return 0, false
		}

		val = (val * 10) + f64(ch & 0xf)
	}

	if i < len(str) && str[i] == '.' {
		pow10: f64 = 10
		i += 1

		for ; i < len(str); i += 1 {
			ch := str[i]

			if ch < '0' || ch > '9' {
				return 0, false
			}

			val += f64(ch & 0xf) / pow10
			pow10 *= 10
		}
	}

	return sign * val, true
}

distance :: proc(p1, p2: Vec2) -> f64 {
	dx := p2.x - p1.x
	dy := p2.y - p1.y
	return math.sqrt((dx * dx) + (dy * dy))
}

geomean :: proc(a, b: f64) -> f64 {
	return math.sqrt(a * b)
}

trunc_string :: proc(str: string, pad, max_width: f64) -> string {
	text_width := int(math.floor((max_width - (pad * 2)) / ch_width))
	max_chars := max(0, min(len(str), text_width))
	chopped_str := str[:max_chars]
	if max_chars != len(str) {
		chopped_str = fmt.tprintf("%s…", chopped_str[:len(chopped_str)-1])
	}

	return chopped_str
}

slice_to_type :: proc(buf: []u8, $T: typeid) -> (T, bool) #optional_ok {
    if len(buf) < size_of(T) {
        return {}, false
    }

    return intrinsics.unaligned_load((^T)(raw_data(buf))), true
}
