class Alldoc < Formula
  desc "Native macOS document search & manager (name + full-text)"
  homepage "https://github.com/rescenedev/alldoc"
  url "https://github.com/rescenedev/alldoc/releases/download/v0.1.1/AllDoc-v0.1.1.zip"
  sha256 "2fadd4515fae95c02032c0dbe28a2c815c299cc3290e161f6ba655f050d34c0f"
  version "0.1.1"
  license "MIT"
  head "https://github.com/rescenedev/alldoc.git", branch: "main"

  depends_on "fd"
  depends_on "fzf"
  depends_on "poppler" # pdftotext (PDF 본문 추출 가속)
  depends_on macos: :sonoma # macOS 14+

  def install
    prefix.install "AllDoc.app"
  end

  def caveats
    <<~EOS
      AllDoc.app 가 설치되었습니다. 실행:
        open #{prefix}/AllDoc.app
      Applications 에 링크하려면:
        ln -sf #{prefix}/AllDoc.app /Applications/AllDoc.app
    EOS
  end

  test do
    assert_predicate prefix/"AllDoc.app", :exist?
  end
end
