package main

import "core:fmt"
import "core:os"
import "core:bytes"
import "core:slice"
import "core:mem"
import "core:math"

/*
Handy References:
- https://llvm.org/docs/PDB/MsfFile.html
- https://github.com/dotnet/runtime/blob/main/docs/design/specs/PE-COFF.md
*/

DOS_MAGIC  := []u8{ 0x4d, 0x5a }
PE32_MAGIC := []u8{ 'P', 'E', 0, 0 }
PDB_MAGIC := []u8{
	'M', 'i', 'c', 'r', 'o', 's', 'o', 'f', 't', ' ', 'C', '/', 'C', '+', '+',
	' ', 'M', 'S', 'F', ' ', '7', '.', '0', '0', '\r', '\n', 0x1A, 0x44, 0x53, 0, 0, 0,
}

DEBUG_TYPE_CODEVIEW :: 2
COFF_Header :: struct #packed {
	machine:              u16,
	section_count:        u16,
	timestamp:            u32,
	symbol_table_offset:  u32,
	symbol_count:         u32,
	optional_header_size: u16,
	flags:                u16,
}

Data_Directory :: struct #packed {
	virtual_addr: u32,
	size:         u32,
}

COFF_Optional_Header :: struct #packed {
	magic:                u16,
	linker_major_version:  u8,
	linker_minor_version:  u8,
	code_size:            u32,
	init_data_size:       u32,
	uninit_data_size:     u32,
	entrypoint_addr:      u32,
	code_base:            u32,
	image_base:           u64,
	section_align:        u32,
	file_align:           u32,
	os_major_version:     u16,
	os_minor_version:     u16,
	image_major_version:  u16,
	image_minor_version:  u16,
	subsystem_major_version: u16,
	subsystem_minor_version: u16,
	win32_version:        u32,
	image_size:           u32,
	headers_size:         u32,
	checksum:             u32,
	subsystem:            u16,
	dll_flags:            u16,
	reserve_stack_size:   u64,
	commit_stack_size:    u64,
	reserve_heap_size:    u64,
	commit_heap_size:     u64,
	loader_flags:         u32,
	rva_and_sizes_count:  u32,
	data_directories:     [16]Data_Directory,
}

COFF_Section_Header :: struct #packed {
	name:             [8]u8,
	virtual_size:       u32,
	virtual_addr:       u32,
	raw_data_size:      u32,
	raw_data_offset:    u32,
	reloc_offset:       u32,
	line_number_offset: u32,
	relocation_count:   u16,
	line_number_count:  u16,
	flags:              u32,
}

PE32_Header :: struct #packed {
	magic: [4]u8,
	coff_header: COFF_Header,
	optional_header: COFF_Optional_Header,
}

COFF_Debug_Directory :: struct #packed {
	flags:           u32,
	timestamp:       u32,
	major_version:   u16,
	minor_version:   u16,
	type:            u32,
	data_size:       u32,
	raw_data_addr:   u32,
	raw_data_offset: u32,
}

COFF_Debug_Entry :: struct #packed {
	signature: [4]u8,
	guid:     [16]u8,
	age:         u32,
}

PDB_MSF_Header :: struct #packed {
	magic:           [32]u8,
	block_size:         u32,
	free_block_map_idx: u32,
	block_count:        u32,
	directory_size:     u32,
	reserved:           u32,
}

PDB_DBI_Header :: struct #packed {
	signature:                  u32,
	version:                    u32,
	age:                        u32,
	global_stream_idx:          u16,
	build_idx:                  u16,
	public_stream_idx:          u16,
	pdb_dll_version:            u16,
	sym_record_stream:          u16,
	pdb_dll_rebuild:            u16,
	mod_info_size:              u32,
	section_contrib_size:       u32,
	section_map_size:           u32,
	source_info_size:           u32,
	type_server_size:           u32,
	mfc_type_server_idx:        u32,
	optional_debug_header_size: u32,
	ec_subsystem_size:          u32,
	flags:                      u16,
	machine:                    u16,
	pad:                        u32,
}

PDB_Named_Stream_Map :: struct #packed {
	length:              u32,
}

PDB_Section_Contrib_Entry :: struct #packed {
	section:    u16,
	padding:  [2]u8,
	offset:     i32,
	size:       i32,
	flags:      u32,
	module_idx: u16,
	padding2: [2]u8,
	data_crc:   u32,
	reloc_crc:  u32,
}

PDB_ModuleInfo :: struct #packed {
	reserved:             u32,
	section_contrib:      PDB_Section_Contrib_Entry,
	flags:                u16,
	module_symbol_stream: u16,
	symbol_size:          u32,
	c11_size:             u32,
	c13_size:             u32,
	source_file_count:    u16,
	padding:            [2]u8,
	reserved2:            u32,
	source_file_name_idx: u32,
	file_path_name_idx:   u32,
}

PDB_Stream_Header :: struct #packed {
	signature: u32,
	version:   u32,
	size:      u32,
	guid:   [16]u8,
}

PDB_Proc32 :: struct #packed {
	record_length:    u16,
	record_type:      u16,
	parent_offset:    u32,
	block_end_offset: u32,
	next_offset:      u32,
	proc_length:      u32,
	dbg_start_offset: u32,
	dbg_end_offset:   u32,
	type_id:          u32,
	offset:           u32,
	segment:          u16,
	flags:             u8,
}

load_pe32 :: proc(trace: ^Trace, exec_buffer: []u8) -> bool {
	pdb_path := ""
	{
		dos_end_offset := 0x3c
		pe_hdr_offset := slice_to_type(exec_buffer[dos_end_offset:], u32) or_return

		cur_offset := int(pe_hdr_offset)
		pe_hdr := slice_to_type(exec_buffer[cur_offset:], PE32_Header) or_return

		if !bytes.equal(pe_hdr.magic[:], PE32_MAGIC) {
			return false
		}

		cur_offset += size_of(PE32_Header)
		section_bytes := (size_of(COFF_Section_Header) * int(pe_hdr.coff_header.section_count))

		// 6 is always debug
		debug_rva := pe_hdr.optional_header.data_directories[6].virtual_addr
		for i := 0; i < int(pe_hdr.coff_header.section_count); i += 1 {
			section_offset := i * size_of(COFF_Section_Header)
			section_hdr := slice_to_type(exec_buffer[cur_offset+section_offset:], COFF_Section_Header) or_return

			start := section_hdr.virtual_addr
			end   := start + section_hdr.virtual_size
			if debug_rva < start || (debug_rva + size_of(COFF_Debug_Directory)) > end {
				continue
			}

			section_relative_offset := debug_rva - start
			dir_offset := section_hdr.raw_data_offset + section_relative_offset
			debug_dir := slice_to_type(exec_buffer[dir_offset:], COFF_Debug_Directory) or_return
			if debug_dir.type != DEBUG_TYPE_CODEVIEW {
				break
			}

			if debug_dir.data_size <= size_of(COFF_Debug_Entry) {
				break
			}

			pdb_path = string(cstring(raw_data(exec_buffer[debug_dir.raw_data_offset+size_of(COFF_Debug_Entry):])))
			break
		}
	}
	if pdb_path == "" {
		return false
	}

	fmt.printf("PDB is at %s\n", pdb_path)
	{
		pdb_buffer, ok := os.read_entire_file_from_filename(pdb_path)
		if !ok {
			return false
		}
		defer delete(pdb_buffer)

		msf_hdr := slice_to_type(pdb_buffer, PDB_MSF_Header) or_return
		if !bytes.equal(msf_hdr.magic[:], PDB_MAGIC) {
			return false
		}

		// TODO: support other block sizes? Is this even a thing?
		if msf_hdr.block_size != 0x1000 {
			return false
		}

		// PDB is complete nonsense. 
		// At the bottom of the PDB header is an array of offsets. The array of offsets get you blocks, containing offsets.
		// *THOSE* offsets get you the blocks containing the data to figure out what your data is.

		directory_block_count := div_ceil(msf_hdr.block_count, msf_hdr.block_size)
		msf_end_buffer := pdb_buffer[size_of(PDB_MSF_Header):]
		directory_block_offsets := slice.reinterpret([]u32, msf_end_buffer[:directory_block_count * size_of(u32)])
		directory_offsets := linearize_msf_stream(pdb_buffer, directory_block_offsets, msf_hdr.block_size, directory_block_count * size_of(u32))
		directory_stream  := linearize_msf_stream(pdb_buffer, slice.reinterpret([]u32, directory_offsets), msf_hdr.block_size, msf_hdr.block_count)

		stream_count := slice.reinterpret([]u32, directory_stream)[0]
		stream_sizes := slice.reinterpret([]u32, directory_stream)[1:1+stream_count]
		
		fmt.printf("Number of streams in file: %d\n", stream_count)
		for i := 0; i < len(stream_sizes); i += 1 {
			fmt.printf("Stream %d -- blocks: %d ", i, div_ceil(stream_sizes[i], msf_hdr.block_size))
			if i > 0 && i % 5 == 0 {
				fmt.printf("\n")
			}
		}
		fmt.printf("\n")
	}

	return false
}

linearize_msf_stream :: proc(data: []u8, indices: []u32, block_size: u32, stream_size: u32) -> []u8 {
	block_count := div_ceil(stream_size, block_size)
	linear_space := make([]u8, block_count * block_size)

	full_block_count, leftovers := math.divmod(stream_size, block_size)
	fmt.printf("got %d blocks!\n", full_block_count + (leftovers > 0 ? 1 : 0))

	copy_offset : u32 = 0
	for i : u32 = 0; i < full_block_count; i += 1 {
		data_offset := indices[i] * block_size
		mem.copy(raw_data(linear_space[copy_offset:]), raw_data(data[data_offset:]), int(block_size))
		copy_offset += block_size
	}

	if leftovers > 0 {
		data_offset := indices[block_count - 1] * block_size
		mem.copy(raw_data(linear_space[copy_offset:]), raw_data(data[data_offset:]), int(leftovers))
	}

	return linear_space
}
