defmodule WeZip do
  alias WeZip.ZipWriter

  def write_local_file_header(params) do
    ZipWriter.write_local_file_header(params)
  end

  def write_data_descriptor(params) do
    ZipWriter.write_data_descriptor(params)
  end
end
