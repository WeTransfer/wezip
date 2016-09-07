defmodule WeZip.ZipWriter do
  use Bitwise

  @four_byte_max_uint 0xFFFFFFFF
  @two_byte_max_uint 0xFFFF

  @zip_tricks_comment "Written using ZipTricks 0.0.1"

  @version_made_by 52
  @version_needed_to_extract 20
  @version_needed_to_extract_zip64 45

  def write_local_file_header(%{
    io: io, filename: filename, storage_mode: storage_mode, compressed_size: compressed_size,
    uncompressed_size: uncompressed_size, crc32: crc32, gp_flags: gp_flags, mtime: mtime
  }) do
    requires_zip64 = (compressed_size > @two_byte_max_uint || uncompressed_size > @four_byte_max_uint)

    # FIRST: not required version
    metadata = [
      io,
      pack_4b(0x04034b50),                         # local file header signature 4 bytes  (0x04034b50)
      pack_2b(@version_needed_to_extract),         # version needed to extract   2 bytes
      pack_2b(gp_flags),                           # general purpose bit flag    2 bytes
      pack_2b(storage_mode),                       # compression method          2 bytes
      pack_2b(to_binary_dos_time(mtime) |> round), # last mod file time          2 bytes
      pack_2b(to_binary_dos_date(mtime) |> round), # last mod file date          2 bytes
      pack_4b(crc32),                              # crc-32                      4 bytes
      pack_4b(compressed_size),                    # compressed size             4 bytes
      pack_4b(uncompressed_size),                  # uncompressed size           4 bytes
      pack_2b(byte_size(filename)),                # file name length            2 bytes
      pack_2b(0),                                  # extra field length          2 bytes
      filename                                     # file name (variable size)
    ] |> Enum.join

    {:ok, pid} = StringIO.open(metadata)

    pid
  end

  # def write_data_descriptor(params) do
  #
  # end
  #
  # def write_central_directory_file_header(params) do
  #
  # end
  #
  # def write_end_of_central_directory(params) do
  #
  # end

  defp pack_4b(x) do
    <<x::little-integer-size(32)>>
  end

  defp pack_2b(x) do
    <<x::little-integer-size(16)>>
  end

  defp to_binary_dos_time(time) do
    (time.second / 2) + (time.minute <<< 5) + (time.hour <<< 11)
  end

  defp to_binary_dos_date(date) do
    date.day + (date.month <<< 5) + ((date.year - 1980) <<< 9)
  end
end
