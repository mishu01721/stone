# Generated by BabelSDK





module Dropbox
  module API

    # Use this class to make Dropbox API calls.  You'll need to obtain an OAuth 2 access token
    # first; you can get one using either WebAuth or WebAuthNoRedirect.
    class Client

      # Args:
      # * +oauth2_access_token+: Obtained via DropboxOAuth2Flow or DropboxOAuth2FlowNoRedirect.
      # * +locale+: The user's current locale (used to localize error messages).
      def initialize(oauth2_access_token, client_identifier = '', root = 'auto', locale = nil)
        unless oauth2_access_token.is_a?(String)
          fail ArgumentError, "oauth2_access_token must be a String; got #{ oauth2_access_token.inspect }"
        end
        @session = Dropbox::API::Session.new(oauth2_access_token, client_identifier, locale)
        @root = root.to_s  # If they passed in a symbol, make it a string

        unless ['dropbox', 'app_folder', 'auto'].include?(@root)
          fail ArgumentError, 'root must be "dropbox", "app_folder", or "auto"'
        end

        # App Folder is the name of the access type, but for historical reasons
        # sandbox is the URL root component that indicates this
        if @root == 'app_folder'
          @root = 'sandbox'
        end
      end

      # Get user account information.
      #
      # Args:
      #
      # Returns:
      #   AccountInfo
      def account_info()
        input = {
        }
        response = @session.do_get(Dropbox::API::API_SERVER, "/account/info", input)
        Dropbox::API::AccountInfo.from_hash(Dropbox::API::HTTP.parse_response(response))
      end
      
      # Downloads a file. Note that this call goes to api-content.dropbox.com
      # instead of api.dropbox.com.
      #
      # Args:
      # * +path+ (+String+):
      #   The path to the file you want to retrieve.
      # * +rev+ (+String+):
      #   The revision of the file to retrieve. This defaults to the most recent
      #   revision.
      #
      # Returns:
      #   EntryInfo
      def get_file(path = nil, rev = nil)
        input = {
          rev: rev,
        }
        response = @session.do_get(Dropbox::API::API_CONTENT_SERVER, "/files/auto/#{ format_path(path, true) }", input)
        parsed_response = Dropbox::API::HTTP.parse_response(response, true)
        metadata = parse_metadata(response)
        return parsed_response, metadata
      end
      
      # Uploads a file using PUT semantics. Note that this call goes to api-
      # content.dropbox.com instead of api.dropbox.com.
      #
      # Args:
      # * +path+ (+String+):
      #   path The full path to the file you want to write to. This parameter
      #   should not point to a folder.
      # * +overwrite+ (+Boolean+):
      #   This value, either true (default) or false, determines what happens
      #   when there's already a file at the specified path. If true, the
      #   existing file will be overwritten by the new one. If false, the new
      #   file will be automatically renamed (for example, test.txt might be
      #   automatically renamed to test (1).txt). The new name can be obtained
      #   from the returned metadata.
      # * +parent_rev+ (+String+):
      #   If present, this parameter specifies the revision of the file you're
      #   editing. If parent_rev matches the latest version of the file on the
      #   user's Dropbox, that file will be replaced. Otherwise, the new file
      #   will be automatically renamed (for example, test.txt might be
      #   automatically renamed to test (conflicted copy).txt). If you specify a
      #   parent_rev and that revision doesn't exist, the file won't save. Get
      #   the most recent rev by performing a call to /metadata.
      #
      # Returns:
      #   EntryInfo
      def put_file(path = nil, overwrite = nil, parent_rev = nil, data = nil)
        input = {
          overwrite: overwrite,
          parent_rev: parent_rev,
        }
        response = @session.do_put(Dropbox::API::API_CONTENT_SERVER, "/files_put/auto/#{ format_path(path, true) }", input, {}, data)
        Dropbox::API::EntryInfo.from_hash(Dropbox::API::HTTP.parse_response(response))
      end
      
      # Retrieves file and folder metadata.
      #
      # Args:
      # * +path+ (+String+):
      #   The path to the file or folder.
      # * +file_limit+ (+UInt32()+):
      #   Default is 10,000 (max is 25,000). When listing a folder, the service
      #   won't report listings containing more than the specified amount of
      #   files and will instead respond with a 406 (Not Acceptable) status
      #   response.
      # * +hash+ (+String+):
      #   Each call to /metadata on a folder will return a hash field, generated
      #   by hashing all of the metadata contained in that response. On later
      #   calls to /metadata, you should provide that value via this parameter
      #   so that if nothing has changed, the response will be a 304 (Not
      #   Modified) status code instead of the full, potentially very large,
      #   folder listing. This parameter is ignored if the specified path is
      #   associated with a file or if list=false. A folder shared between two
      #   users will have the same hash for each user.
      # * +list+ (+Boolean+):
      #   The strings true and false are valid values. true is the default. If
      #   true, the folder's metadata will include a contents field with a list
      #   of metadata entries for the contents of the folder. If false, the
      #   contents field will be omitted.
      # * +include_deleted+ (+Boolean+):
      #   Only applicable when list is set. If this parameter is set to true,
      #   then contents will include the metadata of deleted children. Note that
      #   the target of the metadata call is always returned even when it has
      #   been deleted (with is_deleted set to true) regardless of this flag.
      # * +rev+ (+String+):
      #   If you include a particular revision number, then only the metadata
      #   for that revision will be returned.
      # * +include_media_info+ (+Boolean+):
      #   If true, each file will include a photo_info dictionary for photos and
      #   a video_info dictionary for videos with additional media info. If the
      #   data isn't available yet, the string pending will be returned instead
      #   of a dictionary.
      #
      # Returns:
      #   FileOrFolderInfo
      def metadata(path = nil, file_limit = nil, hash = nil, list = nil, include_deleted = nil, rev = nil, include_media_info = nil)
        input = {
          file_limit: file_limit,
          hash: hash,
          list: list,
          include_deleted: include_deleted,
          rev: rev,
          include_media_info: include_media_info,
        }
        response = @session.do_get(Dropbox::API::API_SERVER, "/metadata/auto/#{ format_path(path, true) }", input)
        Dropbox::API::FileOrFolderInfo.from_hash(Dropbox::API::HTTP.parse_response(response))
      end
      

      private

      # From the oauth spec plus "/".  Slash should not be ecsaped
      RESERVED_CHARACTERS = /[^a-zA-Z0-9\-\.\_\~\/]/  # :nodoc:

      def format_path(path, escape = true) # :nodoc:
        # replace multiple slashes with a single one
        path.gsub!(/\/+/, '/')

        # ensure the path starts with a slash
        path.gsub!(/^\/?/, '/')

        # ensure the path doesn't end with a slash
        path.gsub!(/\/?$/, '')

        escape ? URI.escape(path, RESERVED_CHARACTERS) : path
      end

      # Parses out file metadata from a raw dropbox HTTP response.
      #
      # Args:
      # * +response+: The raw, unparsed HTTPResponse from Dropbox.
      #
      # Returns:
      # * The metadata of the file as a hash.
      def parse_metadata(response) # :nodoc:
        begin
          raw_metadata = response['x-dropbox-metadata']
          metadata = JSON.parse(raw_metadata)
        rescue
          raise DropboxError.new("Dropbox Server Error: x-dropbox-metadata=#{raw_metadata}",
                       response)
        end
        return metadata
      end

    end
  end
end