require 'spec_helper'
require 'tempfile'

describe ActivePdftk::Call do
  context "#new" do
    before :all do
      options = {}
      options[:path] = ENV['path'] unless ENV['path'].nil?
      @pdftk = ActivePdftk::Call.new(options)
    end

    it "should set the path (not nil)"do
      @pdftk.default_statements[:path].should_not be_nil
    end

    it "should check the ENV vars" do
      unless ENV['path'].nil? || ENV['version'].nil?
        ENV['path'].should_not be_nil
        ENV['version'].should_not be_nil
      else
        warn "\nWARNING\nUnable to test path detection and custom setting.\nProvide rake argument to test them.\n`$ rake spec path=/usr/bin/pdftk version=1.44`\n"
      end
    end

    if ENV['path']
      it "should find the path of pdftk (unstable)" do
        ActivePdftk::Call.locate_pdftk.should == ENV['path']
      end

      it "should allow a custom path" do # not very testing ~!?
        @pdftk = ActivePdftk::Call.new(:path => @pdftk.default_statements[:path])
        @pdftk.default_statements[:path].should == @pdftk.default_statements[:path]
      end
    end

    if ENV['version']
      it "should find the version of pdftk (unstable)" do
        @pdftk.pdftk_version.should == ENV['version']
      end
    end

    it "should store default options" do
      path =  ActivePdftk::Call.new.locate_pdftk
      @pdftk = ActivePdftk::Call.new(:input => 'test.pdf', :options => {:flatten => true})
      @pdftk.default_statements.should == {:input => 'test.pdf', :options => {:flatten => true}, :path => path}
    end
  end

  context "#set_cmd" do
    context "prepare command" do
      before :all do
        @pdftk = ActivePdftk::Call.new
      end

      it "should convert input" do
        @pdftk.set_cmd(:input => 'multi.pdf').should == %w(multi.pdf output -)
        inputs = {'multi.pdf' => 'foo', 'poly.pdf' => 'bar', 'spec.c.pdf' => nil}
        reconstruct_inputs(@pdftk.set_cmd(:input => inputs)).should == inputs
        @pdftk.set_cmd(:input => File.new(path_to_pdf('spec.fields.pdf'))).should == %w(- output -)
        @pdftk.set_cmd(:input => Tempfile.new('specs')).should == %w(- output -)
        @pdftk.set_cmd(:input => StringIO.new('specs')).should == %w(- output -)
      end

      it "should convert operation" do
        @pdftk.set_cmd(:operation => {:fill_form => 'a.fdf'}).should == %w(fill_form a.fdf output -)
        @pdftk.set_cmd(:operation => {:fill_form => Tempfile.new('specs')}).should == %w(fill_form - output -)
        @pdftk.set_cmd(:operation => {}).should == %w(output -)
        @pdftk.set_cmd(:operation => 'dump_data_fields').should == %w(dump_data_fields output -)
        @pdftk.set_cmd(:operation => :dump_data_fields).should == %w(dump_data_fields output -)
        @pdftk.set_cmd(:operation => {:dump_data => nil}).should == %w(dump_data output -)
        @pdftk.set_cmd(:operation => {:update_info => 'a.info'}).should == %w(update_info a.info output -)
      end

      it "should convert options" do
        @pdftk.set_cmd(:options => {:owner_pw => 'bar'}).should == %w(output - owner_pw bar)
        @pdftk.set_cmd(:options => {:encrypt  => :'40bit'}).should == %w(output - encrypt_40bit)
        @pdftk.set_cmd(:options => {:allow  => ['DegradedPrinting', :assembly]}).should == %w(output - allow printing degradedprinting modifycontents assembly copycontents screenreaders modifyannotations fillin allfeatures)
      end

      it "should convert output" do
        @pdftk.set_cmd(:output => 'multi.pdf').should == %w(output multi.pdf)
        @pdftk.set_cmd(:output => File.new(path_to_pdf('spec.fields.pdf'))).should == %w(output -)
        @pdftk.set_cmd(:output => Tempfile.new('specs')).should == %w(output -)
        @pdftk.set_cmd(:output => StringIO.new('specs')).should == %w(output -)
        @pdftk.set_cmd({}).should == %w(output -)
        @pdftk.set_cmd(:output => nil).should == %w(output -)
      end

      it "should raise an ActivePdftk::IllegalStatement exception" do
        expect{ @pdftk.pdftk(:options => {:ionize => true}) }.to raise_error(ActivePdftk::IllegalStatement)
        expect{ @pdftk.pdftk(:operation => {:vote => 'for_me'}) }.to raise_error(ActivePdftk::IllegalStatement)
        expect{ @pdftk.pdftk(:options => {:fill_form => 'a.fdf'}) }.to raise_error(ActivePdftk::IllegalStatement)
        expect{ @pdftk.pdftk(:operation => {:flatten => true}) }.to raise_error(ActivePdftk::IllegalStatement)
      end
    end

    context "build_range_option" do
      before :all do
        @pdftk = ActivePdftk::Call.new
      end

      it "should set the operation with arguments" do
        cat_options = {
          :input => {'multi.pdf' => nil, 'poly.pdf' => nil, 'spec.c.pdf' => nil},
          :operation => {
            :cat => [
              {:start => 1, :end => 'end', :pdf => 'multi.pdf'},
              {:pdf => 'poly.pdf', :start => 12, :end => 16, :orientation => 'E', :pages => 'even'}
            ]
          }
        }
        cmd = @pdftk.set_cmd(cat_options)
        input_pdfs = cmd.join(' ').split(' cat ').first
        input_map = map_inputs(input_pdfs)
        cmd.should == %w(B=poly.pdf C=spec.c.pdf D=multi.pdf cat D1-end B12-16evenE output -)

        @pdftk.set_cmd(:input => {'multi.pdf' => nil}, :operation => {:cat => [{:pdf => 'multi.pdf', :start => 1, :end => 'end'}]}).should == %w(B=multi.pdf cat B1-end output -)
        @pdftk.set_cmd(:input => {'multi.pdf' => nil}, :operation => {:cat => [{:pdf => 'multi.pdf'}]}).should == %w(B=multi.pdf cat B output -)

        cat_options = {:input => {'multi.pdf' => nil, 'poly.pdf' => nil}, :operation => {:cat => [{:pdf => 'multi.pdf'}, {:pdf => 'poly.pdf'}]}}
        cmd = @pdftk.set_cmd(cat_options)
        input_pdfs = cmd.join(' ').split(' cat ').first
        input_map = map_inputs(input_pdfs)
        cmd.should == %w(B=poly.pdf C=multi.pdf cat C B output -)

        @pdftk.set_cmd(:input => 'multi.pdf', :operation => {:cat => [{:pdf => 'multi.pdf', :start => 1, :end => 'end'}]}).should == %w(multi.pdf cat 1-end output -)
        @pdftk.set_cmd(:input => 'multi.pdf', :operation => {:cat => [{:pdf => 'multi.pdf', :end => 'end'}]}).should == %w(multi.pdf cat 1-end output -)
        @pdftk.set_cmd(:input => 'multi.pdf', :operation => {:cat => [{:pdf => 'multi.pdf', :start => '4', :orientation => 'N'}]}).should == %w(multi.pdf cat 4N output -)
      end

      it "should raise missing input errors" do
        expect { @pdftk.set_cmd(:input => {'multi.pdf' => nil}, :operation => {:cat => [{:pdf => 'multi.pdf'}, {:pdf => 'poly.pdf'}]}) }.to raise_error(ActivePdftk::MissingInput)
        expect { @pdftk.set_cmd(:input => 'multi.pdf', :operation => {:cat => [{:pdf => 'multi.pdf'}, {:pdf => 'poly.pdf'}]}) }.to raise_error(ActivePdftk::MissingInput)
        expect { @pdftk.set_cmd(:input => {'multi.pdf' => nil, 'spec.c.pdf' => 'foo'}, :operation => {:cat => [{:pdf => 'multi.pdf'}, {:pdf => 'poly.pdf'}]}) }.to raise_error(ActivePdftk::MissingInput, "Missing Input file, `poly.pdf`")
      end

      it "should raise an invalid options error" do
        expect { @pdftk.set_cmd(:input => {'multi.pdf' => nil}, :operation => {:cat => nil}) }.to raise_error(ActivePdftk::InvalidOptions, "Invalid options passed to the command, `cat`, please see `$: pdftk --help`")
        expect { @pdftk.set_cmd(:input => {'multi.pdf' => nil}, :operation => {:cat => []}) }.to raise_error(ActivePdftk::InvalidOptions, "Invalid options passed to the command, `cat`, please see `$: pdftk --help`")
        expect { @pdftk.set_cmd(:input => {'multi.pdf' => nil}, :operation => {:cat => "test"}) }.to raise_error(ActivePdftk::InvalidOptions, "Invalid options passed to the command, `cat`, please see `$: pdftk --help`")
      end
    end

    context "build command" do
      before :all do
        @pdftk = ActivePdftk::Call.new(:input => 'test.pdf', :options => {:flatten => true})
      end

      it "should use default command statements" do
        @pdftk.set_cmd().should == %w(test.pdf output -  flatten)
      end

      it "should overwrite default command statements" do
        @pdftk.set_cmd(:options => { :flatten => false, :owner_pw => 'bar'}).should == %w(test.pdf output - owner_pw bar)
      end

      it "should raise an ActivePdftk::MultipleInputStream exception" do
        expect{ @pdftk.set_cmd(:input => Tempfile.new('specs'), :operation => {:fill_form => StringIO.new('')}) }.to raise_error(ActivePdftk::MultipleInputStream)
      end
    end
  end

  context "#pdftk" do
    before :each do
      @pdftk = ActivePdftk::Call.new
      @file = File.new path_to_pdf('spec.fields.pdf')
      @tempfile = Tempfile.new('specs')
      @stringio = StringIO.new
      @file_as_string = @file.read
      @file.rewind
    end

    it "should input without exception" do
      @tempfile.write @file_as_string
      @stringio.write @file_as_string
      @tempfile.rewind
      @stringio.rewind

      expect{ @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :dump_data) }.to_not raise_error(ActivePdftk::CommandError)
      expect{ @pdftk.pdftk(:input => @file, :operation => :dump_data) }.to_not raise_error(ActivePdftk::CommandError)
      expect{ @pdftk.pdftk(:input => @tempfile, :operation => :dump_data) }.to_not raise_error(ActivePdftk::CommandError)
      expect{ @pdftk.pdftk(:input => @stringio, :operation => :dump_data) }.to_not raise_error(ActivePdftk::CommandError)
    end

    it "should output without exception and give the appropriate result" do
      @data_string = File.new(path_to_pdf('call/fields.data')).read

      expect{ @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :dump_data, :output => @tempfile) }.to_not raise_error(ActivePdftk::CommandError)
      @tempfile.rewind
      @tempfile.read.should == @data_string

      expect{ @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :dump_data, :output => @stringio) }.to_not raise_error(ActivePdftk::CommandError)
      @stringio.string.should == @data_string

      expect{@return_stringio =  @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :dump_data) }.to_not raise_error(ActivePdftk::CommandError)
      @return_stringio.string.should == @data_string
    end

    it "should input a File, output a StringIO without exception and give the appropriate result" do
      @data_fields_string = File.new(path_to_pdf('call/fields.data_fields')).read
      expect{ @pdftk.pdftk(:input => @file, :operation => :dump_data_fields, :output => @stringio) }.to_not raise_error(ActivePdftk::CommandError)
      @stringio.string.should == @data_fields_string
    end

    it "should raise a ActivePdftk::CommandError exception" do
      expect{ @pdftk.pdftk(:input => {'multi.pdf' => 'foo', 'poly.pdf' => 'bar', 'spec.c.pdf' => nil}, :operation => {}, :output => 'out.pdf',:options => { :flatten => false, :owner_pw => 'bar', :user_pw => 'baz', :encrypt  => :'40bit'}) }.to raise_error(ActivePdftk::CommandError)
    end

    context "#burst" do
      it "should return Dir.tmpdir when there is no output specified" do
        @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :burst).should be_a(StringIO)
      end

      it "should return the specified output directory" do
        @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :burst, :output => path_to_pdf('pg_%02d.pdf')).should == path_to_pdf('pg_%02d.pdf')
        File.unlink(path_to_pdf('pg_01.pdf')).should == 1
      end
    end

    context "#unpack_files" do
      it "should return Dir.tmpdir when there is no output specified" do
        @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => {:attach_files => path_to_pdf('call/attached_file.txt')}, :output => path_to_pdf('output.spec'))
        @pdftk.pdftk(:input => path_to_pdf('output.spec'), :operation => :unpack_files).should be_a(StringIO)
        #File.unlink(path_to_pdf('attached_file.txt'))
      end

      it "should return the specified output directory" do
        @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => {:attach_files => path_to_pdf('call/attached_file.txt')}, :output => path_to_pdf('output.spec'))
        @pdftk.pdftk(:input => path_to_pdf('output.spec'), :operation => :unpack_files, :output => path_to_pdf(nil)).should == path_to_pdf(nil)
        File.unlink(path_to_pdf('attached_file.txt'))
      end
    end

    context "respect output formats" do
      it "should return a file as output" do
        @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :dump_data, :output => File.new(path_to_pdf('output.spec'), "w")).should be_a(File)
        File.unlink(path_to_pdf('output.spec')).should == 1
      end

      it "should return a tempfile as output" do
        @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :dump_data, :output => Tempfile.new('output.spec')).should be_a(Tempfile)
      end

      it "should return stringio as output" do
        @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :dump_data, :output => StringIO.new).should be_a(StringIO)
      end

      it "should return a string as output" do
        @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :dump_data, :output => path_to_pdf('output.spec')).should be_a(String)
        File.unlink(path_to_pdf('output.spec')).should == 1
      end

      it "should return stringio if no output is specified" do
        @pdftk.pdftk(:input => path_to_pdf('spec.fields.pdf'), :operation => :dump_data).should be_a(StringIO)
      end
    end
  end
end
