package main

import "core:fmt"
import "core:strings"

MACH_MAGIC_64 :: 0xfeedfacf

MACH_CMD_SYMTAB      :: 0x2
MACH_CMD_SEGMENT_64  :: 0x19
MACH_FILETYPE_EXEC   :: 2
MACH_FILETYPE_DSYM   :: 10
Mach_Header_64 :: struct #packed {
	magic:       u32,
	cpu_type:    u32,
	cpu_subtype: u32,
	file_type:   u32,
	cmd_count:   u32,
	cmd_size:    u32,
	flags:       u32,
	reserved:    u32,
}

Mach_Load_Command :: struct #packed {
	type: u32,
	size: u32,
}

Mach_Segment_64_Command :: struct #packed {
	type:                u32,
	size:                u32,
	name:             [16]u8,
	address:             u64,
	mem_size:            u64,
	file_offset:         u64,
	file_size:           u64,
	max_protection:      i32,
	init_protection:     i32,
	section_count:       u32,
	flags:               u32,
}

Mach_Section :: struct #packed {
	name:         [16]u8,
	segment_name: [16]u8,
	address:         u64,
	size:            u64,
	offset:          u32,
	align:           u32,
	reloc_offset:    u32,
	reloc_count:     u32,
	flags:           u32,
	_rsv1:           u32,
	_rsv2:           u32,
	_rsv3:           u32,
}

Mach_Symtab_Command :: struct #packed {
	type:                u32,
	size:                u32,
	symbol_table_offset: u32,
	symbol_count:        u32,
	string_table_offset: u32,
	string_table_size:   u32,
}

Mach_Symbol_Entry_64 :: struct #packed {
	string_table_idx: u32,
	type: u8,
	section_count: u8,
	description: u16,
	value: u64,
}

load_macho_symbols :: proc(trace: ^Trace, exec_buffer: []u8) -> bool {
	if len(exec_buffer) < size_of(Mach_Header_64) {
		return false
	}

	header := slice_to_type(exec_buffer, Mach_Header_64) or_return
	if header.file_type != MACH_FILETYPE_EXEC {
		return false
	}

	symtab_header := Mach_Symtab_Command{}

	read_idx := size_of(Mach_Header_64)
	for read_idx < len(exec_buffer) {
		current_buffer := exec_buffer[read_idx:]
		cmd := slice_to_type(exec_buffer[read_idx:], Mach_Load_Command) or_return
		if cmd.size == 0 {
			return false
		}

		if cmd.type == MACH_CMD_SYMTAB {
			symtab_header = slice_to_type(exec_buffer[read_idx:], Mach_Symtab_Command) or_return
			break
		} 

		read_idx += int(cmd.size)
	}
	if read_idx >= len(exec_buffer) {
		return false
	}
	
	symbol_table_size := symtab_header.symbol_count * size_of(Mach_Symbol_Entry_64)
	if len(exec_buffer) < int(symtab_header.symbol_table_offset + symbol_table_size) ||
	   len(exec_buffer) < int(symtab_header.string_table_offset + symtab_header.string_table_size) {
		return false
	}

	tmp_buffer := make([]u8, 1024*1024, context.temp_allocator)
	skew_size : u64 = 0
	symbol_found := false
	symbol_table_bytes := exec_buffer[symtab_header.symbol_table_offset:]
	string_table_bytes := exec_buffer[symtab_header.string_table_offset:]
	for i := 0; i < int(symtab_header.symbol_count); i += 1 {
		symbol_buffer := exec_buffer[int(symtab_header.symbol_table_offset)+(i * size_of(Mach_Symbol_Entry_64)):]
		symbol := slice_to_type(symbol_buffer, Mach_Symbol_Entry_64) or_return
		symbol_name := string(cstring(raw_data(string_table_bytes[symbol.string_table_idx:])))

		demangled_name, ok2 := demangle_symbol(symbol_name, tmp_buffer)
		if !ok2 {
			return false
		}

		interned_symbol := in_get(&trace.intern, &trace.string_block, demangled_name)
		am_insert(&trace.addr_map, symbol.value, interned_symbol)

		if !symbol_found && symbol_name == "_spall_auto_init" {
			skew_size = trace.skew_address - u64(symbol.value)
			symbol_found = true
		}
	}

	am_skew(&trace.addr_map, skew_size)
	return true
}

load_macho_debug :: proc(trace: ^Trace, exec_buffer: []u8) -> bool {
	if len(exec_buffer) < size_of(Mach_Header_64) {
		return false
	}

	header := slice_to_type(exec_buffer, Mach_Header_64) or_return
	if header.file_type != MACH_FILETYPE_DSYM {
		return false
	}

	abbrev_section := Mach_Section{}
	info_section   := Mach_Section{}
	line_section   := Mach_Section{}
	found_debug := 0

	read_idx := size_of(Mach_Header_64)
	for read_idx < len(exec_buffer) {
		current_buffer := exec_buffer[read_idx:]
		cmd := slice_to_type(exec_buffer[read_idx:], Mach_Load_Command) or_return
		if cmd.size == 0 {
			return false
		}

		if cmd.type == MACH_CMD_SEGMENT_64 {
			segment_header := slice_to_type(exec_buffer[read_idx:], Mach_Segment_64_Command) or_return
			segment_name := strings.string_from_null_terminated_ptr(raw_data(segment_header.name[:]), 16)
			if segment_name == "__DWARF" {

				sub_idx := read_idx + size_of(Mach_Segment_64_Command)
				end_idx := read_idx + int(cmd.size)
				for sub_idx < end_idx {
					section := slice_to_type(exec_buffer[sub_idx:], Mach_Section) or_return
					section_name := strings.string_from_null_terminated_ptr(raw_data(section.name[:]), 16)

					switch section_name {
					case "__debug_abbrev": abbrev_section = section; found_debug += 1
					case "__debug_info":   info_section   = section; found_debug += 1
					case "__debug_line":   line_section   = section; found_debug += 1
					}

					sub_idx += size_of(Mach_Section)
				}
				break
			}
		}

		read_idx += int(cmd.size)
	}
	if read_idx >= len(exec_buffer) {
		return false
	}
	if found_debug < 3 {
		return false
	}

	// Start parsing DWARF normally from here

	return true
}
