require "minitest_helper"

class ParserTest < Minitest::Test
  def test_with_no_structured_data
    parser = Syslog::Parser.new

    line = "<34>1 2003-10-11T22:14:15.003Z mymachine.example.com su - ID47 - "\
      "'su root' failed for lonvick on /dev/pts/8"
    message = parser.parse(line)

    assert_equal 34, message.prival
    assert_equal 4, message.facility
    assert_equal 2, message.severity
    assert_equal 1, message.version
    assert_equal(
      Time.utc(2003, 10, 11, 22, 14, Rational('15003/1000')),
      message.timestamp,
    )
    assert_equal "mymachine.example.com", message.hostname
    assert_equal "su", message.app_name
    assert_nil message.procid
    assert_equal "ID47", message.msgid
    assert_nil message.structured_data
    assert_equal "'su root' failed for lonvick on /dev/pts/8", message.msg

    line = "<165>1 2003-08-24T05:14:15.000003-07:00 192.0.2.1 myproc 8710 - "\
      "- %% It's time to make the do-nuts."
    message = parser.parse(line)

    assert_equal 165, message.prival
    assert_equal 20, message.facility
    assert_equal 5, message.severity
    assert_equal 1, message.version
    assert_equal(
      Time.new(2003, 8, 24, 5, 14, Rational('15000003/1000000'), '-07:00'),
      message.timestamp,
    )
    assert_equal "192.0.2.1", message.hostname
    assert_equal "myproc", message.app_name
    assert_equal "8710", message.procid
    assert_nil message.msgid
    assert_nil message.structured_data
    assert_equal "%% It's time to make the do-nuts.", message.msg
  end

  def test_with_structured_data
    parser = Syslog::Parser.new

    line = '<165>1 2003-10-11T22:14:15.003Z mymachine.example.com evntslog - '\
      'ID47 [exampleSDID@32473 iut="3" eventSource="Application" '\
      'eventID="1011"] An application event log entry...'
    message = parser.parse(line)

    assert_equal 165, message.prival
    assert_equal 20, message.facility
    assert_equal 5, message.severity
    assert_equal 1, message.version
    assert_equal(
      Time.utc(2003, 10, 11, 22, 14, Rational('15003/1000')),
      message.timestamp,
    )
    assert_equal "mymachine.example.com", message.hostname
    assert_equal "evntslog", message.app_name
    assert_nil message.procid
    assert_equal "ID47", message.msgid
    assert_equal 1, message.structured_data.length
    assert_equal "exampleSDID@32473", message.structured_data[0].id
    params = {
      "iut" => "3",
      "eventSource" => "Application",
      "eventID" => "1011",
    }
    assert_equal params, message.structured_data[0].params
    assert_equal "An application event log entry...", message.msg
  end

  def test_structured_data_only
    parser = Syslog::Parser.new

    line = '<165>1 2003-10-11T22:14:15.003Z mymachine.example.com evntslog - '\
      'ID47 [exampleSDID@32473 iut="3" eventSource="Application" '\
      'eventID="1011"][examplePriority@32473 class="high"]'
    message = parser.parse(line)

    assert_equal 165, message.prival
    assert_equal 20, message.facility
    assert_equal 5, message.severity
    assert_equal 1, message.version
    assert_equal(
      Time.utc(2003, 10, 11, 22, 14, Rational('15003/1000')),
      message.timestamp,
    )
    assert_equal "mymachine.example.com", message.hostname
    assert_equal "evntslog", message.app_name
    assert_nil message.procid
    assert_equal "ID47", message.msgid
    assert_equal 2, message.structured_data.length
    assert_equal "exampleSDID@32473", message.structured_data[0].id
    params = {
      "iut" => "3",
      "eventSource" => "Application",
      "eventID" => "1011",
    }
    assert_equal params, message.structured_data[0].params
    assert_equal "examplePriority@32473", message.structured_data[1].id
    params = { "class" => "high" }
    assert_equal params, message.structured_data[1].params
    assert_nil message.msg
  end

  def test_escaping_in_param_value
    parser = Syslog::Parser.new

    line = '<165>1 2003-10-11T22:14:15.003Z mymachine.example.com evntslog - '\
      'ID47 [exampleSDID@32473 escape="\"\\\\\]"]'
    message = parser.parse(line)

    assert_equal 165, message.prival
    assert_equal 20, message.facility
    assert_equal 5, message.severity
    assert_equal 1, message.version
    assert_equal(
      Time.utc(2003, 10, 11, 22, 14, Rational('15003/1000')),
      message.timestamp,
    )
    assert_equal "mymachine.example.com", message.hostname
    assert_equal "evntslog", message.app_name
    assert_nil message.procid
    assert_equal "ID47", message.msgid
    assert_equal 1, message.structured_data.length
    assert_equal "exampleSDID@32473", message.structured_data[0].id
    params = { "escape" => "\"\\\\\]" }
    assert_equal params, message.structured_data[0].params
    assert_nil message.msg
  end

  def test_malformed_message
    parser = Syslog::Parser.new

    line = '<165>1 -10-11T22:14:15.003Z mymachine.example.com evntslog - '\
      'ID47 [exampleSDID@32473 escape="\"\\\\\]"]'

    error = assert_raises(Syslog::Parser::Error) { parser.parse(line) }

    message = "Failed to match sequence (HEADER SP STRUCTURED_DATA (SP MSG)?) "\
      "at line 1 char 1."
    assert_equal message, error.message
  end

  def test_allow_missing_structured_data
    parser = Syslog::Parser.new(allow_missing_structured_data: true)

    line = "<40>1 2012-11-30T06:45:29+00:00 host app web.3 - State changed "\
      "from starting to up"
    message = parser.parse(line)

    assert_equal 40, message.prival
    assert_equal 5, message.facility
    assert_equal 0, message.severity
    assert_equal 1, message.version
    assert_equal Time.utc(2012, 11, 30, 6, 45, 29), message.timestamp
    assert_equal "host", message.hostname
    assert_equal "app", message.app_name
    assert_equal "web.3", message.procid
    assert_nil message.msgid
    assert_nil message.structured_data
    assert_equal "State changed from starting to up", message.msg
  end

  def test_message_attribute_classes
    parser = Syslog::Parser.new

    line = '<165>1 2003-10-11T22:14:15.003Z hostname app_name procid msgid '\
      '[id param_name="param_value"] msg'
    message = parser.parse(line)

    assert_equal Integer, message.prival.class
    assert_equal Integer, message.facility.class
    assert_equal Integer, message.severity.class
    assert_equal Integer, message.version.class
    assert_equal Time, message.timestamp.class
    assert_equal String, message.hostname.class
    assert_equal String, message.app_name.class
    assert_equal String, message.procid.class
    assert_equal String, message.msgid.class
    assert_equal String, message.structured_data[0].id.class
    assert_equal String, message.structured_data[0].params.keys.first.class
    assert_equal String, message.structured_data[0].params.values.first.class
    assert_equal String, message.msg.class
  end
end
