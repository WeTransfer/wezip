defmodule WeZip do
  alias WeZip.ZipWriter

  def write_local_file_header(params) do
    ZipWriter.write_local_file_header(params)
  end
end
