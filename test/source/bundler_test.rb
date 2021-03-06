# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("bundle")
  describe Licensed::Source::Bundler do
    let(:fixtures) { File.expand_path("../../fixtures/bundler", __FILE__) }
    let(:config) { Licensed::Configuration.new }
    let(:source) { Licensed::Source::Bundler.new(config) }

    before do
      @original_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
    end

    after do
      ENV["BUNDLE_GEMFILE"] = @original_bundle_gemfile
    end

    describe "enabled?" do
      it "is true if Gemfile.lock exists" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false no Gemfile.lock exists" do
        Dir.chdir(Dir.tmpdir) do
          refute source.enabled?
        end
      end
    end

    describe "gemfile_path" do
      it "returns a the path to Gemfile local to the current directory" do
        Dir.mktmpdir do |tmp|
          bundle_gemfile_path = File.join(tmp, "gems.rb")
          File.write(bundle_gemfile_path, "")
          ENV["BUNDLE_GEMFILE"] = bundle_gemfile_path

          path = File.join(tmp, "bundler")
          Dir.mkdir(path)
          Dir.chdir(path) do
            File.write("Gemfile", "")
            assert_equal Pathname.pwd.join("Gemfile"), source.gemfile_path
          end
        end
      end

      it "returns a the path to gems.rb local to the current directory" do
        Dir.mktmpdir do |tmp|
          bundle_gemfile_path = File.join(tmp, "Gemfile")
          File.write(bundle_gemfile_path, "")
          ENV["BUNDLE_GEMFILE"] = bundle_gemfile_path

          path = File.join(tmp, "bundler")
          Dir.mkdir(path)
          Dir.chdir(path) do
            File.write("gems.rb", "")
            assert_equal Pathname.pwd.join("gems.rb"), source.gemfile_path
          end
        end
      end

      it "prefers Gemfile over gems.rb" do
        Dir.mktmpdir do |tmp|
          Dir.chdir(tmp) do
            File.write("Gemfile", "")
            File.write("gems.rb", "")
            assert_equal Pathname.pwd.join("Gemfile"), source.gemfile_path
          end
        end
      end

      it "returns nil if a gem file can't be found" do
        ENV["BUNDLE_GEMFILE"] = nil
        Dir.mktmpdir do |tmp|
          Dir.chdir(tmp) do
            assert_nil source.gemfile_path
          end
        end
      end
    end

    describe "lockfile_path" do
      it "returns nil if gemfile_path is nil" do
        source.stub(:gemfile_path, nil) do
          assert_nil source.lockfile_path
        end
      end

      it "returns Gemfile.lock for Gemfile gemfile_path" do
        Dir.mktmpdir do |tmp|
          Dir.chdir(tmp) do
            File.write("Gemfile", "")
            assert_equal Pathname.pwd.join("Gemfile.lock"), source.lockfile_path
          end
        end
      end

      it "returns gems.rb.lock for gems.rb gemfile_path" do
        Dir.mktmpdir do |tmp|
          Dir.chdir(tmp) do
            File.write("gems.rb", "")
            assert_equal Pathname.pwd.join("gems.rb.lock"), source.lockfile_path
          end
        end
      end
    end

    describe "dependencies" do
      it "finds dependencies from Gemfile" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.find { |d| d["name"] == "semantic" }
          assert dep
          assert_equal "1.6.0", dep["version"]
        end
      end

      it "finds platform-specific dependencies" do
        Dir.chdir(fixtures) do
          assert source.dependencies.find { |d| d["name"] == "libv8" }
        end
      end

      it "finds dependencies from path sources" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.find { |d| d["name"] == "pathed-gem-fixture" }
          assert dep
          assert_equal "0.0.1", dep["version"]
        end
      end

      describe "when bundler is a listed dependency" do
        it "includes bundler as a dependency" do
          Dir.chdir(fixtures) do
            assert source.dependencies.find { |d| d["name"] == "bundler" }
          end
        end
      end

      describe "when bundler is not explicitly listed as a dependency" do
        let(:config) { Licensed::Configuration.new("rubygems" => { "without" => "bundler" }) }

        it "does not include bundler as a dependency" do
          Dir.chdir(fixtures) do
            assert_nil source.dependencies.find { |d| d["name"] == "bundler" }
          end
        end
      end


      describe "with excluded groups in the configuration" do
        let(:config) { Licensed::Configuration.new("rubygems" => { "without" => "exclude" }) }

        it "ignores gems in the excluded groups" do
          Dir.chdir(fixtures) do
            assert_nil source.dependencies.find { |d| d["name"] == "i18n" }
          end
        end

        it "does not ignore gems from development and test" do
          Dir.chdir(fixtures) do
            # test
            dep = source.dependencies.find { |d| d["name"] == "minitest" }
            assert dep
            assert_equal "5.11.3", dep["version"]

            # dev
            dep = source.dependencies.find { |d| d["name"] == "tzinfo" }
            assert dep
            assert_equal "1.2.5", dep["version"]
          end
        end
      end

      it "ignores gems from development and test by default" do
        Dir.chdir(fixtures) do
          # test
          assert_nil source.dependencies.find { |d| d["name"] == "minitest" }

          # dev
          assert_nil source.dependencies.find { |d| d["name"] == "tzinfo" }
        end
      end

      it "ignores gems from bundler-configured 'without' groups" do
        Dir.chdir(fixtures) do
          assert_nil source.dependencies.find { |d| d["name"] == "json" }
        end
      end

      it "ignores local gemspecs" do
        fixtures = File.expand_path("../../fixtures/bundler", __FILE__)
        Dir.chdir(fixtures) do
          assert_nil source.dependencies.find { |d| d["name"] == "licensed" }
        end
      end
    end
  end
end
