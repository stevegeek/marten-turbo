require "../spec_helper"

describe MartenTurbo::Verifier do
  describe ".sign and .verify" do
    it "round-trips a stream name" do
      signed = MartenTurbo::Verifier.sign("messages")
      MartenTurbo::Verifier.verify(signed).should eq("messages")
    end

    it "round-trips a stream name with special characters" do
      signed = MartenTurbo::Verifier.sign("user_42/messages?room=general")
      MartenTurbo::Verifier.verify(signed).should eq("user_42/messages?room=general")
    end

    it "is deterministic for the same input + secret" do
      a = MartenTurbo::Verifier.sign("foo")
      b = MartenTurbo::Verifier.sign("foo")
      a.should eq(b)
    end
  end

  describe ".verify rejection" do
    it "rejects nil" do
      MartenTurbo::Verifier.verify(nil).should be_nil
    end

    it "rejects empty string" do
      MartenTurbo::Verifier.verify("").should be_nil
    end

    it "rejects malformed values" do
      MartenTurbo::Verifier.verify("nodelimiter").should be_nil
      MartenTurbo::Verifier.verify("--onlyhash").should be_nil
      MartenTurbo::Verifier.verify("onlymsg--").should be_nil
    end

    it "rejects a tampered message" do
      signed = MartenTurbo::Verifier.sign("messages")
      msg, _, sig = signed.partition("--")
      tampered = "#{Base64.urlsafe_encode("messages_evil", padding: false)}--#{sig}"
      MartenTurbo::Verifier.verify(tampered).should be_nil
    end

    it "rejects a tampered signature" do
      signed = MartenTurbo::Verifier.sign("messages")
      msg, _, sig = signed.partition("--")
      tampered = "#{msg}--#{sig.reverse}"
      MartenTurbo::Verifier.verify(tampered).should be_nil
    end
  end
end
