# encoding: UTF-8
require_relative 'test_helper'

class PrettyPrintTests < Minitest::Test
  OP1 = {
    :block => %w(root block structure div),
    :compact => %w(p),
    :inline => %w(i),
    :preserve_whitespace => true,
    :delete_all_linebreaks => true,
    :tab => '  '
  }

  OP2 = {
    :block => %w(root),
    :compact => %w(p),
    :inline => %w(i),
    :preserve_whitespace => false,
    :tab => '  '
  }

  OP3 = {
    :block => %w(root),
    :compact => %w(p),
    :inline => %w(i),
    :tab => '  '
  }

  OP4 = {
    :block => %w(root style block structure div),
    :compact => %w(p),
    :inline => %w(i),
    :preserve_whitespace => true,
    :preserve_linebreaks => ['style'],
    :tab => '  '
  }

  def setup_and_exercise(options)
    @pp = PrettyXML::PrettyPrint.new(options).pp(@input)
  end

  def test_strips_inline_and_compact_space_when_ws_is_false
    @input = "<root>  <p> </p><p>stuff<i> </i></p>  </root>"
    setup_and_exercise OP2
    assert @pp =~ /<p\/>/
    assert @pp =~ /<i\/>/
    assert @pp !~ /<root>  <p>/
  end

  def test_ws_preserve_defaults_to_true_if_not_given
    @input = "<root>  <p> </p><p>stuff<i> </i></p>  </root>"
    setup_and_exercise OP3
    assert @pp =~ /<p> <\/p>/
    assert @pp =~ /<i> <\/i>/
    assert @pp !~ /<root>  <p>/
  end

  def test_nonsensical_content_model_does_not_explode
    @input = "<root>  <i>stuff<p> </p></i>  </root>"
    setup_and_exercise OP1
    assert @pp
  end

  def test_badly_specified_root_node_doesnt_break
    @input = "<p>  <i>stuff<root> </root></i>  </p>"
    setup_and_exercise OP1
    assert @pp =~/\n\s+<root/
  end

  def test_internal_linebreak_strip_works
    @input = "<root>  <p>linebreak goes
here</p>  </root>"
    setup_and_exercise OP1
    assert @pp !~ /<p>[^<]*\n/
  end

  def test_retains_space_between_inline_els
    @input = "<root><p>this <i>word</i> <i>and</i> this</p></root>"
    setup_and_exercise OP1
    assert @pp =~ /<\/i> <i>/
  end

  def test_comment_in_self_closing_tag
    @input = "<root><p><i><!-- comment --></i></p></root>"
    expected_middle = /<p><i><!-- comment --><\/i><\/p>/
    setup_and_exercise OP1
    assert @pp =~ expected_middle
  end

  def test_with_xmldec_and_processing_inst
    @input = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><?xml-stylesheet type=\"text/xsl\" href=\"style.xsl\"?><!DOCTYPE sam PUBLIC \"-//Scribe, Inc.//DTD sam v1.2.0//EN\" \"http://scribenet.com/get/doctype/scml_dtds/2.1.0/sam.dtd\"><root><p/></root>"
    setup_and_exercise OP1
    assert @pp =~ /<\?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"\?>\n/
    assert @pp =~ /<\?xml-stylesheet [^>]*>\n/
    assert @pp =~ /<!DOCTYPE [^>]*>\n/
  end

  def test_can_preserve_specified_linebreaks
    @input = <<-EOF
<root>
<style>
bq {}
eq {}
</style>
<p><i><!-- comment --></i></p></root>
EOF
    setup_and_exercise OP4
    assert @pp.scan(/\}\n/).size > 1
  end

  def test_can_treat_comments_contextually
    @input = <<-EOF
<root>
<p>foo</p><!--<p>foo</p>-->
</root>
EOF
    output = <<-OUT
<root>
  <p>foo</p>
  <!--<p>foo</p>-->
</root>
OUT
    setup_and_exercise OP1
    assert @pp.strip == output.strip, "expected:\n#{output}\ngot:\n#{@pp}"
  end

  def test_more_complex_example
    @input = Examples.example1[:in]
    setup_and_exercise OP1
    expected = Examples.example1[:out]
    assert @pp == expected, "It looked like this: \n#{@pp}"
  end

  def test_raises_nonwellformed_error
    @input = '<root><p></root>'
    assert_raises(Nokogiri::XML::SyntaxError) {
      setup_and_exercise(OP1)
    }
  end

  def test_selfclosing_input
    @input = '<root><block><block/></block></root>'
    setup_and_exercise(OP1)
    assert Nokogiri.XML(@pp).errors.empty?
  end

  def test_retains_cdata
    expected = 'some text content'
    @input = <<-XML
<root>
<![CDATA[#{expected}]]>
</root>
XML
    setup_and_exercise(OP1)
    assert @pp[expected]
  end

  def test_compact_parent_of_compact_behaves_as_block
    @input = <<-XML
<root>
<p><p/></p>
</root>
XML
    expected = <<-OP
<root>
  <p>
    <p/>
  </p>
</root>
OP
    setup_and_exercise(OP1)
    assert @pp[expected.strip]
  end

  def test_compact_parent_of_block_behaves_as_block
    @input = <<-XML
<root>
<p><block/></p>
</root>
XML
    expected = <<-OP
<root>
  <p>
    <block/>
  </p>
</root>
OP
    setup_and_exercise(OP1)
    assert @pp[expected.strip]
  end

  def test_normalize
    @input = <<-XML
<root>
<p>a\u0300</p>
</root>
XML
    expected = <<-XML
<root>
  <p>à</p>
</root>
XML
    options = OP1.dup.merge(normalize: true)
    setup_and_exercise(options)
    assert_equal expected.strip, @pp
  end

  module Examples
    def self.example1
      {:in => '<root>  <block>
 <p> </p>

    </block><p>stuff<i> </i></p>

    <structure>
                       <div>
                       <p>yo yo<i/></p>
</div>
</structure> <structure>
                       <div>
                       <p>yo yo<i/></p>
</div>
</structure></root>',
      :out => '<root>
  <block>
    <p> </p>
  </block>
  <p>stuff<i> </i></p>
  <structure>
    <div>
      <p>yo yo<i/></p>
    </div>
  </structure>
  <structure>
    <div>
      <p>yo yo<i/></p>
    </div>
  </structure>
</root>'
      }
    end
  end
end
