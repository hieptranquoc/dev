require_relative '../logging'

module TeracyDev
  module Location
    class GitSynch

      def initialize
        @logger = TeracyDev::Logging.logger_for(self.class.name)
      end
      # return true if sync action is carried out, otherwise, return false
      def sync(location, sync_existing)
        @logger.debug("git_sync: location: #{location}; sync_existing: #{sync_existing}")
        updated = false
        return updated if ! Util.exist? location['git']

        git = location['git']
        branch = location['branch'] ||= 'master'
        tag = location['tag']
        ref = location['ref']
        lookup_path = location['lookup_path']
        path = location['path']
        dir = location['dir']

        if File.exist? path
          if sync_existing == true
            @logger.debug("git_sync: sync existing, location: #{location}")

            Dir.chdir(path) do
              @logger.debug("Checking #{path}")

              current_git = `git remote get-url origin`.strip

              current_ref = `git rev-parse --verify HEAD`.strip

              if current_git != git
                `git remote remove origin`

                `git remote add origin #{git}`
                updated = true
              end

              if ref
                updated = check_ref(current_ref, ref)
              elsif tag
                updated = check_tag(current_ref, tag)
              else
                branch ||= 'master'

                updated = check_branch(current_ref, branch)
              end
            end
          end
        else
          if Vagrant::Util::Which.which('git') == nil
            @logger.error("git is not avaiable")
            abort
          end
          Dir.chdir(lookup_path) do
            @logger.info("cd #{lookup_path} && git clone #{git} #{dir}")
            system("git clone #{git} #{dir}")
          end

          Dir.chdir(path) do
            @logger.info("cd #{path} && git checkout #{branch}")
            system("git checkout #{branch}")
          end
          updated = true
        end
        updated
      end


    private

    def check_ref(current_ref, ref_string)
      @logger.debug("Ref detected, checking out #{ref_string}")
      updated = false
      if !current_ref.start_with? ref_string
        `git fetch origin`

        `git checkout #{ref_string}`
        updated = true
      end
      updated
    end

    def check_tag(current_ref, desired_tag)
      @logger.debug("Sync with tags/#{desired_tag}")
      updated = false
      cmd = "git show-ref --tags #{desired_tag} | sed 's/ .*//'"

      @logger.debug("tag present: #{Util.exist? `#{cmd}`.strip}")

      # fetch origin if tag is not present
      `git fetch origin` if !Util.exist? `#{cmd}`.strip

      tag_ref = `#{cmd}`.strip

      @logger.debug("current_ref: #{current_ref} - tag_ref: #{tag_ref}")

      if current_ref != tag_ref
        `git checkout tags/#{desired_tag}`
        updated = true
      end
      updated
    end

    def check_branch(current_ref, desired_branch)
      @logger.debug("Sync with origin/#{desired_branch}")
      updated = false
      current_branch = `git rev-parse --abbrev-ref HEAD`.strip

      # branch master/develop are always get update
      # 
      # other branch is only get update once
      if ['master', 'develop'].include? desired_branch
        `git fetch origin`
      # only fetch if it is valid branch and not other (tags, ref, ...)
      elsif desired_branch != current_branch and current_branch != 'HEAD'
        `git fetch origin`
      end

      @logger.debug("current_branch: #{current_branch} - desired_branch: #{desired_branch}")

      # found no such branch, switch to found as tag
      return check_tag(current_ref, desired_branch) if !File.exist?(
        ".git/refs/heads/#{desired_branch}")

      remote_ref = `git show-ref --head | sed -n 's/ .*\\(refs\\/remotes\\/origin\\/#{desired_branch}\\).*//p'`.strip

      @logger.debug("current_ref: #{current_ref} - remote_ref: #{remote_ref}")

      if current_ref != remote_ref
        `git checkout #{desired_branch}`

        `git reset --hard origin/#{desired_branch}`
        updated = true
      end
      updated
    end

    end
  end
end