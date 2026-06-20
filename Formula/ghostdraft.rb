class Ghostdraft < Formula
  desc "Ephemeral scratch draft on macOS that leaves no disk trace"
  homepage "https://github.com/Di-kairos/ghostdraft"
  url "https://github.com/Di-kairos/ghostdraft/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "90ea5f70dbae0e75e01644d0f28c4a8b8174e4eb7e92a63d987c091cd14e1610"
  license "MIT"

  def install
    bin.install "ghostdraft"
  end

  test do
    assert_match "ghostdraft", shell_output("#{bin}/ghostdraft version")
  end
end
