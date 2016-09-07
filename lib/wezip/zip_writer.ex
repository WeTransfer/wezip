defmodule Wezip.ZipWriter do
  @four_byte_max_uint 0xFFFFFFFF
  @two_byte_max_uint 0xFFFF

  @zip_tricks_comment "Written using ZipTricks 0.0.1"

  @version_made_by 52
  @version_needed_to_extract 20
  @version_needed_to_extract_zip64 45

  defmacro __using__(_) do
    quote do
      def write_local_file_header(params) do

      end

      def write_data_descriptor(params) do

      end

      def write_central_directory_file_header(params) do

      end

      def write_end_of_central_directory(params) do

      end
    end
  end
end
