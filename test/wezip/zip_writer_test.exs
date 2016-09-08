require IEx

defmodule ByteReader do
  def read_2b(pid) do
    <<result::little-integer-size(16)>> = IO.binread(pid, 2)
    result
  end

  def read_4b(pid) do
    <<result::little-integer-size(32)>> = IO.binread(pid, 4)
    result
  end

  def read_8b(pid) do
    <<result::little-integer-size(64)>> = IO.binread(pid, 8)
    result
  end
end

defmodule WeZipTest.ZipWriter do
  use ExUnit.Case

  # #write_local_file_header
  test "writes the local file header for an entry that does not require Zip64" do
    mtime = %DateTime{year: 2016, month: 07, day: 17, zone_abbr: "UTC", hour: 13, minute: 48,
    second: 0, time_zone: "UTC", utc_offset: 0, std_offset: 0}

    pid = WeZip.write_local_file_header(%{
      io: "", gp_flags: 12, crc32: 456, compressed_size: 768, uncompressed_size: 901, mtime: mtime,
      filename: "foo.bin", storage_mode: 8
    })

    assert ByteReader.read_4b(pid) == 0x04034b50 # Signature
    assert ByteReader.read_2b(pid) == 20         # Version needed to extract
    assert ByteReader.read_2b(pid) == 12         # gp flags
    assert ByteReader.read_2b(pid) == 8          # storage mode
    assert ByteReader.read_2b(pid) == 28160      # DOS time
    assert ByteReader.read_2b(pid) == 18673      # DOS date
    assert ByteReader.read_4b(pid) == 456        # CRC32
    assert ByteReader.read_4b(pid) == 768        # compressed size
    assert ByteReader.read_4b(pid) == 901        # uncompressed size
    assert ByteReader.read_2b(pid) == 7          # filename size
    assert ByteReader.read_2b(pid) == 0          # extra fields size
    assert IO.binread(pid, 7) == "foo.bin"       # extra fields size
    assert IO.binread(pid, 1) == :eof
  end

  test "writes the local file header for an entry that does require Zip64 based on uncompressed size (with the Zip64 extra)" do
    mtime = %DateTime{year: 2016, month: 07, day: 17, zone_abbr: "UTC", hour: 13, minute: 48,
    second: 0, time_zone: "UTC", utc_offset: 0, std_offset: 0}

    pid = WeZip.write_local_file_header(%{
      io: "", gp_flags: 12, crc32: 456, compressed_size: 768, uncompressed_size: 0xFFFFFFFF+1,
      mtime: mtime, filename: "foo.bin", storage_mode: 8
    })

    assert ByteReader.read_4b(pid) == 0x04034b50   # Signature
    assert ByteReader.read_2b(pid) == 45           # Version needed to extract
    assert ByteReader.read_2b(pid) == 12           # gp flags
    assert ByteReader.read_2b(pid) == 8            # storage mode
    assert ByteReader.read_2b(pid) == 28160        # DOS time
    assert ByteReader.read_2b(pid) == 18673        # DOS date
    assert ByteReader.read_4b(pid) == 456          # CRC32
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF   # compressed size
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF   # uncompressed size
    assert ByteReader.read_2b(pid) == 7            # filename size
    assert ByteReader.read_2b(pid) == 20           # extra fields size
    assert IO.binread(pid, 7) == "foo.bin"         # extra fields size

    assert ByteReader.read_2b(pid) == 1            # Zip64 extra tag
    assert ByteReader.read_2b(pid) == 16           # Size of the Zip64 extra payload
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF+1 # uncompressed size
    assert ByteReader.read_8b(pid) == 768          # compressed size
  end

  test "writes the local file header for an entry that does require Zip64 based on compressed size (with the Zip64 extra)" do
    mtime = %DateTime{year: 2016, month: 07, day: 17, zone_abbr: "UTC", hour: 13, minute: 48,
    second: 0, time_zone: "UTC", utc_offset: 0, std_offset: 0}

    pid = WeZip.write_local_file_header(%{
      io: "", gp_flags: 12, crc32: 456, compressed_size: 0xFFFFFFFF+1, uncompressed_size: 768,
      mtime: mtime, filename: "foo.bin", storage_mode: 8
    })

    assert ByteReader.read_4b(pid) == 0x04034b50   # Signature
    assert ByteReader.read_2b(pid) == 45           # Version needed to extract
    assert ByteReader.read_2b(pid) == 12           # gp flags
    assert ByteReader.read_2b(pid) == 8            # storage mode
    assert ByteReader.read_2b(pid) == 28160        # DOS time
    assert ByteReader.read_2b(pid) == 18673        # DOS date
    assert ByteReader.read_4b(pid) == 456          # CRC32
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF   # compressed size
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF   # uncompressed size
    assert ByteReader.read_2b(pid) == 7            # filename size
    assert ByteReader.read_2b(pid) == 20           # extra fields size
    assert IO.binread(pid, 7) == "foo.bin"         # extra fields size

    assert ByteReader.read_2b(pid) == 1            # Zip64 extra tag
    assert ByteReader.read_2b(pid) == 16           # Size of the Zip64 extra payload
    assert ByteReader.read_8b(pid) == 768          # uncompressed size
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF+1 # compressed size
  end

  #write_data_descriptor
  test "writes 4-byte sizes into the data descriptor for standard file sizes" do
    pid = WeZip.write_data_descriptor(%{
      io: "", crc32: 123, compressed_size: 89821, uncompressed_size: 990912
    })

    assert ByteReader.read_4b(pid) == 0x08074b50 # Signature
    assert ByteReader.read_4b(pid) == 123        # CRC32
    assert ByteReader.read_4b(pid) == 89821      # compressed size
    assert ByteReader.read_4b(pid) == 990912     # uncompressed size
    assert IO.binread(pid, 1) == :eof
  end

  test "writes 8-byte sizes into the data descriptor for Zip64 compressed file size" do
    pid = WeZip.write_data_descriptor(%{
      io: "", crc32: 123, compressed_size: 0xFFFFFFFF+1, uncompressed_size: 990912
    })

    assert ByteReader.read_4b(pid) == 0x08074b50   # Signature
    assert ByteReader.read_4b(pid) == 123          # CRC32
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF+1 # compressed size
    assert ByteReader.read_8b(pid) == 990912       # uncompressed size
    assert IO.binread(pid, 1) == :eof
  end

  test "writes 8-byte sizes into the data descriptor for Zip64 uncompressed file size" do
    pid = WeZip.write_data_descriptor(%{
      io: "", crc32: 123, compressed_size: 123, uncompressed_size: 0xFFFFFFFF+1
    })

    assert ByteReader.read_4b(pid) == 0x08074b50   # Signature
    assert ByteReader.read_4b(pid) == 123          # CRC32
    assert ByteReader.read_8b(pid) == 123          # compressed size
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF+1 # uncompressed size
    assert IO.binread(pid, 1) == :eof
  end

  # write_central_directory_file_header
  test "writes the file header for a small-ish entry" do
    mtime = %DateTime{year: 2016, month: 02, day: 02, zone_abbr: "UTC", hour: 14, minute: 00,
    second: 0, time_zone: "UTC", utc_offset: 0, std_offset: 0}

    pid = WeZip.write_central_directory_file_header(%{
      io: "", local_file_header_location: 898921, gp_flags: 555, storage_mode: 23, mtime: mtime,
      compressed_size: 901, uncompressed_size: 909102, crc32: 89765, filename: "a-file.txt",
      external_attrs: 123
    })

    assert ByteReader.read_4b(pid) == 0x02014b50 # Central directory entry sig
    assert ByteReader.read_2b(pid) == 820        # version made by
    assert ByteReader.read_2b(pid) == 20         # version need to extract
    assert ByteReader.read_2b(pid) == 555        # general purpose bit flag (explicitly set to bogus value to ensure we pass it through
    assert ByteReader.read_2b(pid) == 23         # compression method (explicitly set to bogus value)
    assert ByteReader.read_2b(pid) == 28672      # last mod file time
    assert ByteReader.read_2b(pid) == 18498      # last mod file date
    assert ByteReader.read_4b(pid) == 89765      # crc32
    assert ByteReader.read_4b(pid) == 901        # compressed size
    assert ByteReader.read_4b(pid) == 909102     # uncompressed size
    assert ByteReader.read_2b(pid) == 10         # filename length
    assert ByteReader.read_2b(pid) == 0          # extra field length
    assert ByteReader.read_2b(pid) == 0          # file comment
    assert ByteReader.read_2b(pid) == 0          # disk number, must be blanked to the maximum value because of The Unarchiver bug
    assert ByteReader.read_2b(pid) == 0          # internal file attributes
    assert ByteReader.read_4b(pid) == 2175008768 # external file attributes
    assert ByteReader.read_4b(pid) == 898921     # relative offset of local header
    assert IO.binread(pid, 10) == "a-file.txt"   # the filename
  end

  test "writes the file header for an entry that requires Zip64 extra because of the uncompressed size" do
    mtime = %DateTime{year: 2016, month: 02, day: 02, zone_abbr: "UTC", hour: 14, minute: 00,
    second: 0, time_zone: "UTC", utc_offset: 0, std_offset: 0}

    pid = WeZip.write_central_directory_file_header(%{
      io: "", local_file_header_location: 898921, gp_flags: 555, storage_mode: 23,
      compressed_size: 901, uncompressed_size: 0xFFFFFFFFF+3, mtime: mtime, crc32: 89765,
      filename: "a-file.txt", external_attrs: 123
    })

    assert ByteReader.read_4b(pid) == 0x02014b50    # Central directory entry sig
    assert ByteReader.read_2b(pid) == 820           # version made by
    assert ByteReader.read_2b(pid) == 45            # version need to extract
    assert ByteReader.read_2b(pid) == 555           # general purpose bit flag (explicitly set to bogus value to ensure we pass it through
    assert ByteReader.read_2b(pid) == 23            # compression method (explicitly set to bogus value)
    assert ByteReader.read_2b(pid) == 28672         # last mod file time
    assert ByteReader.read_2b(pid) == 18498         # last mod file date
    assert ByteReader.read_4b(pid) == 89765         # crc32
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF    # compressed size
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF    # uncompressed size
    assert ByteReader.read_2b(pid) == 10            # filename length
    assert ByteReader.read_2b(pid) == 32            # extra field length
    assert ByteReader.read_2b(pid) == 0             # file comment
    assert ByteReader.read_2b(pid) == 0xFFFF        # disk number, must be blanked to the maximum value because of The Unarchiver bug
    assert ByteReader.read_2b(pid) == 0             # internal file attributes
    assert ByteReader.read_4b(pid) == 2175008768    # external file attributes
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF    # relative offset of local header
    assert IO.binread(pid, 10) == "a-file.txt"      # the filename

    assert ByteReader.read_2b(pid) == 1             # Zip64 extra tag
    assert ByteReader.read_2b(pid) == 28            # Size of the Zip64 extra payload
    assert ByteReader.read_8b(pid) == 0xFFFFFFFFF+3 # uncompressed size
    assert ByteReader.read_8b(pid) == 901           # compressed size
    assert ByteReader.read_8b(pid) == 898921        # local file header location
  end

  test "writes the file header for an entry that requires Zip64 extra because of the compressed size" do
    mtime = %DateTime{year: 2016, month: 02, day: 02, zone_abbr: "UTC", hour: 14, minute: 00,
    second: 0, time_zone: "UTC", utc_offset: 0, std_offset: 0}

    pid = WeZip.write_central_directory_file_header(%{
      io: "", local_file_header_location: 898921, gp_flags: 555, storage_mode: 23,
      compressed_size: 0xFFFFFFFFF+3, uncompressed_size: 901, mtime: mtime, crc32: 89765,
      filename: "a-file.txt", external_attrs: 123
    })

    assert ByteReader.read_4b(pid) == 0x02014b50    # Central directory entry sig
    assert ByteReader.read_2b(pid) == 820           # version made by
    assert ByteReader.read_2b(pid) == 45            # version need to extract
    assert ByteReader.read_2b(pid) == 555           # general purpose bit flag (explicitly set to bogus value to ensure we pass it through
    assert ByteReader.read_2b(pid) == 23            # compression method (explicitly set to bogus value)
    assert ByteReader.read_2b(pid) == 28672         # last mod file time
    assert ByteReader.read_2b(pid) == 18498         # last mod file date
    assert ByteReader.read_4b(pid) == 89765         # crc32
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF    # compressed size
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF    # uncompressed size
    assert ByteReader.read_2b(pid) == 10            # filename length
    assert ByteReader.read_2b(pid) == 32            # extra field length
    assert ByteReader.read_2b(pid) == 0             # file comment
    assert ByteReader.read_2b(pid) == 0xFFFF        # disk number, must be blanked to the maximum value because of The Unarchiver bug
    assert ByteReader.read_2b(pid) == 0             # internal file attributes
    assert ByteReader.read_4b(pid) == 2175008768    # external file attributes
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF    # relative offset of local header
    assert IO.binread(pid, 10) == "a-file.txt"      # the filename

    assert ByteReader.read_2b(pid) == 1             # Zip64 extra tag
    assert ByteReader.read_2b(pid) == 28            # Size of the Zip64 extra payload
    assert ByteReader.read_8b(pid) == 901           # uncompressed size
    assert ByteReader.read_8b(pid) == 0xFFFFFFFFF+3 # compressed size
    assert ByteReader.read_8b(pid) == 898921        # local file header location
  end

  test "writes the file header for an entry that requires Zip64 extra because of the local file header offset being beyound 4GB" do
    mtime = %DateTime{year: 2016, month: 02, day: 02, zone_abbr: "UTC", hour: 14, minute: 00,
    second: 0, time_zone: "UTC", utc_offset: 0, std_offset: 0}

    pid = WeZip.write_central_directory_file_header(%{
      io: "", local_file_header_location: 0xFFFFFFFFF+1, gp_flags: 555, storage_mode: 23,
      compressed_size: 8981, uncompressed_size: 819891, mtime: mtime, crc32: 89765,
      filename: "a-file.txt", external_attrs: 123
    })

    assert ByteReader.read_4b(pid) == 0x02014b50    # Central directory entry sig
    assert ByteReader.read_2b(pid) == 820           # version made by
    assert ByteReader.read_2b(pid) == 45            # version need to extract
    assert ByteReader.read_2b(pid) == 555           # general purpose bit flag (explicitly set to bogus value to ensure we pass it through
    assert ByteReader.read_2b(pid) == 23            # compression method (explicitly set to bogus value)
    assert ByteReader.read_2b(pid) == 28672         # last mod file time
    assert ByteReader.read_2b(pid) == 18498         # last mod file date
    assert ByteReader.read_4b(pid) == 89765         # crc32
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF    # compressed size
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF    # uncompressed size
    assert ByteReader.read_2b(pid) == 10            # filename length
    assert ByteReader.read_2b(pid) == 32            # extra field length
    assert ByteReader.read_2b(pid) == 0             # file comment
    assert ByteReader.read_2b(pid) == 0xFFFF        # disk number, must be blanked to the maximum value because of The Unarchiver bug
    assert ByteReader.read_2b(pid) == 0             # internal file attributes
    assert ByteReader.read_4b(pid) == 2175008768    # external file attributes
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF    # relative offset of local header
    assert IO.binread(pid, 10) == "a-file.txt"      # the filename

    assert ByteReader.read_2b(pid) == 1             # Zip64 extra tag
    assert ByteReader.read_2b(pid) == 28            # Size of the Zip64 extra payload
    assert ByteReader.read_8b(pid) == 819891        # uncompressed size
    assert ByteReader.read_8b(pid) == 8981          # compressed size
    assert ByteReader.read_8b(pid) == 0xFFFFFFFFF+1 # local file header location
  end

  #write_end_of_central_directory
  test "writes out the EOCD with all markers for a small ZIP file with just a few entries" do
    number_of_files = Enum.random(8..190)

    pid = WeZip.write_end_of_central_directory(%{
      io: "", start_of_central_directory_location: 9091211, central_directory_size: 9091,
      num_files_in_archive: number_of_files
    })

    assert ByteReader.read_4b(pid) == 0x06054b50      # EOCD signature
    assert ByteReader.read_2b(pid) == 0               # number of this disk
    assert ByteReader.read_2b(pid) == 0               # number of the disk with the EOCD record
    assert ByteReader.read_2b(pid) == number_of_files # number of files on this disk
    assert ByteReader.read_2b(pid) == number_of_files # number of files in central directory total (for all disks)
    assert ByteReader.read_4b(pid) == 9091            # size of the central directory (cdir records for all files)
    assert ByteReader.read_4b(pid) == 9091211         # start of central directory offset from the beginning of file/disk

    comment_length = ByteReader.read_2b(pid)
    assert comment_length != 0
    assert IO.binread(pid, comment_length) |> String.match?(~r/ZipTricks/) == true
  end

  ## NOTE: This one was a messy code Im not sure if the logic is right here:
  test "writes out the custom comment" do
    comment = "Ohai mate"

    pid = WeZip.write_end_of_central_directory(%{
      io: "", start_of_central_directory_location: 9091211,
      central_directory_size: 9091, num_files_in_archive: 4, comment: comment
    })

    size_and_comment_range = ((byte_size(comment) + 2) * -1)..-1
    size_and_comment = IO.binread(pid, :all) |> String.slice(size_and_comment_range)
    comment_size = size_and_comment |> String.to_charlist |> List.first
    assert comment_size == byte_size(comment)
  end

  test "writes out the Zip64 EOCD as well if the central directory is located beyound 4GB in the archive" do
    number_of_files = Enum.random(8..190)

    pid = WeZip.write_end_of_central_directory(%{
      io: "", start_of_central_directory_location: 0xFFFFFFFF+3, central_directory_size: 9091,
      num_files_in_archive: number_of_files
    })

    assert ByteReader.read_4b(pid) == 0x06064b50            # Zip64 EOCD signature
    assert ByteReader.read_8b(pid) == 44                    # Zip64 EOCD record size
    assert ByteReader.read_2b(pid) == 820                   # Version made by
    assert ByteReader.read_2b(pid) == 45                    # Version needed to extract
    assert ByteReader.read_4b(pid) == 0                     # Number of this disk
    assert ByteReader.read_4b(pid) == 0                     # Number of the disk with the Zip64 EOCD record
    assert ByteReader.read_8b(pid) == number_of_files       # Number of entries in the central directory of this disk
    assert ByteReader.read_8b(pid) == number_of_files       # Number of entries in the central directories of all disks
    assert ByteReader.read_8b(pid) == 9091                  # Central directory size
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF+3          # Start of central directory location


    assert ByteReader.read_4b(pid) == 0x07064b50            # Zip64 EOCD locator signature
    assert ByteReader.read_4b(pid) == 0                     # Number of the disk with the EOCD locator signature
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF + 3 + 9091 # Where the Zip64 EOCD record starts
    assert ByteReader.read_4b(pid) == 1                     # Total number of disks

    # Then the usual EOCD record
    assert ByteReader.read_4b(pid) == 0x06054b50            # EOCD signature
    assert ByteReader.read_2b(pid) == 0                     # number of this disk
    assert ByteReader.read_2b(pid) == 0                     # number of the disk with the EOCD record
    assert ByteReader.read_2b(pid) == 0xFFFF                # number of files on this disk
    assert ByteReader.read_2b(pid) == 0xFFFF                # number of files in central directory total (for all disks)
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF            # size of the central directory (cdir records for all files)
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF            # start of central directory offset from the beginning of file/disk

    comment_length = ByteReader.read_2b(pid)
    assert comment_length != 0
    assert IO.binread(pid, comment_length) |> String.match?(~r/ZipTricks/) == true
  end

  test "writes out the Zip64 EOCD if the archive has more than 0xFFFF files" do
    pid = WeZip.write_end_of_central_directory(%{
      io: "", start_of_central_directory_location: 123, central_directory_size: 9091,
      num_files_in_archive: 0xFFFF+1
    })

    assert ByteReader.read_4b(pid) == 0x06064b50 # Zip64 EOCD signature
    ByteReader.read_8b(pid)
    ByteReader.read_2b(pid)
    ByteReader.read_2b(pid)
    ByteReader.read_4b(pid)
    ByteReader.read_4b(pid)

    assert ByteReader.read_8b(pid) == 0xFFFF+1   # Number of entries in the central directory of this disk
    assert ByteReader.read_8b(pid) == 0xFFFF+1   # Number of entries in the central directories of all disks
  end

  test "writes out the Zip64 EOCD if the central directory size exceeds 0xFFFFFFFF" do
    pid = WeZip.write_end_of_central_directory(%{
      io: "", start_of_central_directory_location: 123, central_directory_size: 0xFFFFFFFF+2,
      num_files_in_archive: 5
    })

    assert ByteReader.read_4b(pid) == 0x06064b50 # Zip64 EOCD signature
    ByteReader.read_8b(pid)
    ByteReader.read_2b(pid)
    ByteReader.read_2b(pid)
    ByteReader.read_4b(pid)
    ByteReader.read_4b(pid)

    assert ByteReader.read_8b(pid) == 5          # Number of entries in the central directory of this disk
    assert ByteReader.read_8b(pid) == 5          # Number of entries in the central directories of all disks
  end
end
