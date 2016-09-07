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

defmodule WezipTest.ZipWriter do
  use ExUnit.Case

  # #write_local_file_header
  test "writes the local file header for an entry that does not require Zip64" do
    # WeZip.write_local_file_header will return pid of the StringIO

    # mtime = Time.utc(2016, 7, 17, 13, 48)

    # pid = WeZip.write_local_file_header(%{
    #   io: buf,
    #   gp_flags: 12,
    #   crc32: 456,
    #   compressed_size: 768,
    #   uncompressed_size: 901,
    #   mtime: mtime,
    #   filename: 'foo.bin',
    #   storage_mode: 8
    # })

    {:ok, pid} = StringIO.open("PK\u0003\u0004\u0014\u0000\f\u0000\b\u0000\u0000n\xF1H\xC8\u0001\u0000\u0000\u0000\u0003\u0000\u0000\x85\u0003\u0000\u0000\a\u0000\u0000\u0000foo.bin")

    assert ByteReader.read_4b(pid) == 0x04034b50
    assert ByteReader.read_2b(pid) == 20
    assert ByteReader.read_2b(pid) == 12
    assert ByteReader.read_2b(pid) == 8
    assert ByteReader.read_2b(pid) == 28160
    assert ByteReader.read_2b(pid) == 18673
    assert ByteReader.read_4b(pid) == 456
    assert ByteReader.read_4b(pid) == 768
    assert ByteReader.read_4b(pid) == 901
    assert ByteReader.read_2b(pid) == 7
    assert ByteReader.read_2b(pid) == 0
    assert IO.binread(pid, 7) == "foo.bin"
    assert IO.binread(pid, 1) == :eof
  end

  test "writes the local file header for an entry that does require Zip64 based on uncompressed size (with the Zip64 extra)" do
    # mtime = Time.utc(2016, 7, 17, 13, 48)

    # pid = WeZip.write_local_file_header(%{})

    {:ok, pid} = StringIO.open("PK\u0003\u0004-\u0000\f\u0000\b\u0000\u0000n\xF1H\xC8\u0001\u0000\u0000\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\a\u0000\u0014\u0000foo.bin\u0001\u0000\u0010\u0000\u0000\u0000\u0000\u0000\u0001\u0000\u0000\u0000\u0000\u0003\u0000\u0000\u0000\u0000\u0000\u0000")

    assert ByteReader.read_4b(pid) == 0x04034b50
    assert ByteReader.read_2b(pid) == 45
    assert ByteReader.read_2b(pid) == 12
    assert ByteReader.read_2b(pid) == 8
    assert ByteReader.read_2b(pid) == 28160
    assert ByteReader.read_2b(pid) == 18673
    assert ByteReader.read_4b(pid) == 456
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_2b(pid) == 7
    assert ByteReader.read_2b(pid) == 20
    assert IO.binread(pid, 7) == "foo.bin"

    assert ByteReader.read_2b(pid) == 1
    assert ByteReader.read_2b(pid) == 16
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF+1
    assert ByteReader.read_8b(pid) == 768
  end

  test "writes the local file header for an entry that does require Zip64 based on compressed size (with the Zip64 extra)" do
    # mtime = Time.utc(2016, 7, 17, 13, 48)

    # pid = WeZip.write_local_file_header(%{})

    {:ok, pid} = StringIO.open("PK\u0003\u0004-\u0000\f\u0000\b\u0000\u0000n\xF1H\xC8\u0001\u0000\u0000\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\a\u0000\u0014\u0000foo.bin\u0001\u0000\u0010\u0000\u0000\u0003\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0001\u0000\u0000\u0000")

    assert ByteReader.read_4b(pid) == 0x04034b50
    assert ByteReader.read_2b(pid) == 45
    assert ByteReader.read_2b(pid) == 12
    assert ByteReader.read_2b(pid) == 8
    assert ByteReader.read_2b(pid) == 28160
    assert ByteReader.read_2b(pid) == 18673
    assert ByteReader.read_4b(pid) == 456
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_2b(pid) == 7
    assert ByteReader.read_2b(pid) == 20
    assert IO.binread(pid, 7) == "foo.bin"

    assert ByteReader.read_2b(pid) == 1
    assert ByteReader.read_2b(pid) == 16
    assert ByteReader.read_8b(pid) == 768
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF+1
  end

  #write_data_descriptor
  test "writes 4-byte sizes into the data descriptor for standard file sizes" do
    {:ok, pid} = StringIO.open("PK\a\b{\u0000\u0000\u0000\xDD^\u0001\u0000\xC0\u001E\u000F\u0000")

    assert ByteReader.read_4b(pid) == 0x08074b50
    assert ByteReader.read_4b(pid) == 123
    assert ByteReader.read_4b(pid) == 89821
    assert ByteReader.read_4b(pid) == 990912
    assert IO.binread(pid, 1) == :eof
  end

  test "writes 8-byte sizes into the data descriptor for Zip64 compressed file size" do
    {:ok, pid} = StringIO.open("PK\a\b{\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0001\u0000\u0000\u0000\xC0\u001E\u000F\u0000\u0000\u0000\u0000\u0000")

    assert ByteReader.read_4b(pid) == 0x08074b50
    assert ByteReader.read_4b(pid) == 123
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF+1
    assert ByteReader.read_8b(pid) == 990912
    assert IO.binread(pid, 1) == :eof
  end

  test "writes 8-byte sizes into the data descriptor for Zip64 uncompressed file size" do
    {:ok, pid} = StringIO.open("PK\a\b{\u0000\u0000\u0000{\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0001\u0000\u0000\u0000")

    assert ByteReader.read_4b(pid) == 0x08074b50
    assert ByteReader.read_4b(pid) == 123
    assert ByteReader.read_8b(pid) == 123
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF+1
    assert IO.binread(pid, 1) == :eof
  end

  # write_central_directory_file_header
  test "writes the file header for a small-ish entry" do
    {:ok, pid} = StringIO.open("PK\u0001\u00024\u0003\u0014\u0000+\u0002\u0017\u0000\u0000pBH\xA5^\u0001\u0000\x85\u0003\u0000\u0000.\xDF\r\u0000\n\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\xA4\x81i\xB7\r\u0000a-file.txt")

    assert ByteReader.read_4b(pid) == 0x02014b50
    assert ByteReader.read_2b(pid) == 820
    assert ByteReader.read_2b(pid) == 20
    assert ByteReader.read_2b(pid) == 555
    assert ByteReader.read_2b(pid) == 23
    assert ByteReader.read_2b(pid) == 28672
    assert ByteReader.read_2b(pid) == 18498
    assert ByteReader.read_4b(pid) == 89765
    assert ByteReader.read_4b(pid) == 901
    assert ByteReader.read_4b(pid) == 909102
    assert ByteReader.read_2b(pid) == 10
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_4b(pid) == 2175008768
    assert ByteReader.read_4b(pid) == 898921
    assert IO.binread(pid, 10) == "a-file.txt"
  end

  test "writes the file header for an entry that requires Zip64 extra because of the uncompressed size" do
    {:ok, pid} = StringIO.open("PK\u0001\u00024\u0003-\u0000+\u0002\u0017\u0000\u0000pBH\xA5^\u0001\u0000\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\n\u0000 \u0000\u0000\u0000\xFF\xFF\u0000\u0000\u0000\u0000\xA4\x81\xFF\xFF\xFF\xFFa-file.txt\u0001\u0000\u001C\u0000\u0002\u0000\u0000\u0000\u0010\u0000\u0000\u0000\x85\u0003\u0000\u0000\u0000\u0000\u0000\u0000i\xB7\r\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000")

    assert ByteReader.read_4b(pid) == 0x02014b50
    assert ByteReader.read_2b(pid) == 820
    assert ByteReader.read_2b(pid) == 45
    assert ByteReader.read_2b(pid) == 555
    assert ByteReader.read_2b(pid) == 23
    assert ByteReader.read_2b(pid) == 28672
    assert ByteReader.read_2b(pid) == 18498
    assert ByteReader.read_4b(pid) == 89765
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_2b(pid) == 10
    assert ByteReader.read_2b(pid) == 32
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_2b(pid) == 0xFFFF
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_4b(pid) == 2175008768
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert IO.binread(pid, 10) == "a-file.txt"

    assert ByteReader.read_2b(pid) == 1
    assert ByteReader.read_2b(pid) == 28
    assert ByteReader.read_8b(pid) == 0xFFFFFFFFF+3
    assert ByteReader.read_8b(pid) == 901
    assert ByteReader.read_8b(pid) == 898921
  end

  test "writes the file header for an entry that requires Zip64 extra because of the compressed size" do
    {:ok, pid} = StringIO.open("PK\u0001\u00024\u0003-\u0000+\u0002\u0017\u0000\u0000pBH\xA5^\u0001\u0000\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\n\u0000 \u0000\u0000\u0000\xFF\xFF\u0000\u0000\u0000\u0000\xA4\x81\xFF\xFF\xFF\xFFa-file.txt\u0001\u0000\u001C\u0000\x85\u0003\u0000\u0000\u0000\u0000\u0000\u0000\u0002\u0000\u0000\u0000\u0010\u0000\u0000\u0000i\xB7\r\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000")

    assert ByteReader.read_4b(pid) == 0x02014b50
    assert ByteReader.read_2b(pid) == 820
    assert ByteReader.read_2b(pid) == 45
    assert ByteReader.read_2b(pid) == 555
    assert ByteReader.read_2b(pid) == 23
    assert ByteReader.read_2b(pid) == 28672
    assert ByteReader.read_2b(pid) == 18498
    assert ByteReader.read_4b(pid) == 89765
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_2b(pid) == 10
    assert ByteReader.read_2b(pid) == 32
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_2b(pid) == 0xFFFF
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_4b(pid) == 2175008768
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert IO.binread(pid, 10) == "a-file.txt"

    assert ByteReader.read_2b(pid) == 1
    assert ByteReader.read_2b(pid) == 28
    assert ByteReader.read_8b(pid) == 901
    assert ByteReader.read_8b(pid) == 0xFFFFFFFFF+3
    assert ByteReader.read_8b(pid) == 898921
  end

  test "writes the file header for an entry that requires Zip64 extra because of the local file header offset being beyound 4GB" do
    {:ok, pid} = StringIO.open("PK\u0001\u00024\u0003-\u0000+\u0002\u0017\u0000\u0000pBH\xA5^\u0001\u0000\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\n\u0000 \u0000\u0000\u0000\xFF\xFF\u0000\u0000\u0000\u0000\xA4\x81\xFF\xFF\xFF\xFFa-file.txt\u0001\u0000\u001C\u0000\xB3\x82\f\u0000\u0000\u0000\u0000\u0000\u0015#\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0010\u0000\u0000\u0000\u0000\u0000\u0000\u0000")

    assert ByteReader.read_4b(pid) == 0x02014b50
    assert ByteReader.read_2b(pid) == 820
    assert ByteReader.read_2b(pid) == 45
    assert ByteReader.read_2b(pid) == 555
    assert ByteReader.read_2b(pid) == 23
    assert ByteReader.read_2b(pid) == 28672
    assert ByteReader.read_2b(pid) == 18498
    assert ByteReader.read_4b(pid) == 89765
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_2b(pid) == 10
    assert ByteReader.read_2b(pid) == 32
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_2b(pid) == 0xFFFF
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_4b(pid) == 2175008768
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert IO.binread(pid, 10) == "a-file.txt"

    assert ByteReader.read_2b(pid) == 1
    assert ByteReader.read_2b(pid) == 28
    assert ByteReader.read_8b(pid) == 819891
    assert ByteReader.read_8b(pid) == 8981
    assert ByteReader.read_8b(pid) == 0xFFFFFFFFF+1
  end

  #write_end_of_central_directory
  test "writes out the EOCD with all markers for a small ZIP file with just a few entries" do
    # number_of_files = Enum.random(8..190)
    number_of_files = 80 # MAKE THIS RANDOM LIKE ABOVE

    {:ok, pid} = StringIO.open("PK\u0005\u0006\u0000\u0000\u0000\u0000P\u0000P\u0000\x83#\u0000\u0000\x8B\xB8\x8A\u0000\u001D\u0000Written using ZipTricks 4.0.0")

    assert ByteReader.read_4b(pid) == 0x06054b50
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_2b(pid) == number_of_files
    assert ByteReader.read_2b(pid) == number_of_files
    assert ByteReader.read_4b(pid) == 9091
    assert ByteReader.read_4b(pid) == 9091211

    comment_length = ByteReader.read_2b(pid)
    assert comment_length != 0
    assert IO.binread(pid, comment_length) |> String.match?(~r/ZipTricks/) == true
  end

  ## TODO: This one was a messy code Im not sure if the logic is right here:
  test "writes out the custom comment" do
    comment = "Ohai mate"

    {:ok, pid} = StringIO.open("PK\x05\x06\x00\x00\x00\x00\x04\x00\x04\x00\x83#\x00\x00\x8B\xB8\x8A\x00\t\x00Ohai mate")

    size_and_comment_range = ((byte_size(comment) + 2) * -1)..-1
    size_and_comment = IO.binread(pid, :all) |> String.slice(size_and_comment_range)
    comment_size = size_and_comment |> String.to_charlist |> List.first
    assert comment_size == byte_size(comment)
  end

  test "writes out the Zip64 EOCD as well if the central directory is located beyound 4GB in the archive" do
    # number_of_files = Enum.random(8..190)
    number_of_files = 135 # MAKE THIS RANDOM LIKE ABOVE
    {:ok, pid} = StringIO.open("PK\u0006\u0006,\u0000\u0000\u0000\u0000\u0000\u0000\u00004\u0003-\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\x87\u0000\u0000\u0000\u0000\u0000\u0000\u0000\x87\u0000\u0000\u0000\u0000\u0000\u0000\u0000\x83#\u0000\u0000\u0000\u0000\u0000\u0000\u0002\u0000\u0000\u0000\u0001\u0000\u0000\u0000PK\u0006\a\u0000\u0000\u0000\u0000\x85#\u0000\u0000\u0001\u0000\u0000\u0000\u0001\u0000\u0000\u0000PK\u0005\u0006\u0000\u0000\u0000\u0000\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\u001D\u0000Written using ZipTricks 4.0.0")

    assert ByteReader.read_4b(pid) == 0x06064b50
    assert ByteReader.read_8b(pid) == 44
    assert ByteReader.read_2b(pid) == 820
    assert ByteReader.read_2b(pid) == 45
    assert ByteReader.read_4b(pid) == 0
    assert ByteReader.read_4b(pid) == 0
    assert ByteReader.read_8b(pid) == number_of_files
    assert ByteReader.read_8b(pid) == number_of_files
    assert ByteReader.read_8b(pid) == 9091
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF+3


    assert ByteReader.read_4b(pid) == 0x07064b50
    assert ByteReader.read_4b(pid) == 0
    assert ByteReader.read_8b(pid) == 0xFFFFFFFF + 3 + 9091
    assert ByteReader.read_4b(pid) == 1

    assert ByteReader.read_4b(pid) == 0x06054b50
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_2b(pid) == 0
    assert ByteReader.read_2b(pid) == 0xFFFF
    assert ByteReader.read_2b(pid) == 0xFFFF
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF
    assert ByteReader.read_4b(pid) == 0xFFFFFFFF

    comment_length = ByteReader.read_2b(pid)
    assert comment_length != 0
    assert IO.binread(pid, comment_length) |> String.match?(~r/ZipTricks/) == true
  end

  test "writes out the Zip64 EOCD if the archive has more than 0xFFFF files" do
    {:ok, pid} = StringIO.open("PK\u0006\u0006,\u0000\u0000\u0000\u0000\u0000\u0000\u00004\u0003-\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0001\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0001\u0000\u0000\u0000\u0000\u0000\x83#\u0000\u0000\u0000\u0000\u0000\u0000{\u0000\u0000\u0000\u0000\u0000\u0000\u0000PK\u0006\a\u0000\u0000\u0000\u0000\xFE#\u0000\u0000\u0000\u0000\u0000\u0000\u0001\u0000\u0000\u0000PK\u0005\u0006\u0000\u0000\u0000\u0000\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\u001D\u0000Written using ZipTricks 4.0.0")

    assert ByteReader.read_4b(pid) == 0x06064b50
    ByteReader.read_8b(pid)
    ByteReader.read_2b(pid)
    ByteReader.read_2b(pid)
    ByteReader.read_4b(pid)
    ByteReader.read_4b(pid)

    assert ByteReader.read_8b(pid) == 0xFFFF+1
    assert ByteReader.read_8b(pid) == 0xFFFF+1
  end

  test "writes out the Zip64 EOCD if the central directory size exceeds 0xFFFFFFFF" do
    {:ok, pid} = StringIO.open("PK\u0006\u0006,\u0000\u0000\u0000\u0000\u0000\u0000\u00004\u0003-\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0005\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0005\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0001\u0000\u0000\u0000\u0001\u0000\u0000\u0000{\u0000\u0000\u0000\u0000\u0000\u0000\u0000PK\u0006\a\u0000\u0000\u0000\u0000|\u0000\u0000\u0000\u0001\u0000\u0000\u0000\u0001\u0000\u0000\u0000PK\u0005\u0006\u0000\u0000\u0000\u0000\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\u001D\u0000Written using ZipTricks 4.0.0")

    assert ByteReader.read_4b(pid) == 0x06064b50
    ByteReader.read_8b(pid)
    ByteReader.read_2b(pid)
    ByteReader.read_2b(pid)
    ByteReader.read_4b(pid)
    ByteReader.read_4b(pid)

    assert ByteReader.read_8b(pid) == 5
    assert ByteReader.read_8b(pid) == 5
  end
end
