class Alldoc < Formula
  desc "Native macOS document search & manager (name + full-text)"
  homepage "https://github.com/rescenedev/alldoc"
  license "MIT"
  head "https://github.com/rescenedev/alldoc.git", branch: "main"

  # 안정 릴리스 태그 생성 후 url/sha256 채움:
  # url "https://github.com/rescenedev/alldoc/archive/refs/tags/v0.1.0.tar.gz"
  # sha256 "REPLACE_WITH_RELEASE_TARBALL_SHA256"

  depends_on "fd"
  depends_on "fzf"
  depends_on "poppler" # pdftotext (PDF 본문 추출 가속)
  depends_on macos: :sonoma # macOS 14+

  def install
    system "./build.sh", "release"
    prefix.install "build/AllDoc.app"
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
