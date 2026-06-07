class Alldoc < Formula
  desc "Native macOS document search & manager (name + full-text)"
  homepage "https://github.com/rescenedev/alldoc"
  url "https://github.com/rescenedev/alldoc/releases/download/v0.1.3/AllDoc.app-0.1.3.zip"
  sha256 "068f1440745b8fc99294fd982dc89a93d13dd842ec0b009f00d6d8babe259826"
  version "0.1.3"
  license "MIT"
  head "https://github.com/rescenedev/alldoc.git", branch: "main"

  depends_on "fd"
  depends_on "fzf"
  depends_on "poppler" # pdftotext (PDF 본문 추출 가속)
  depends_on macos: :sonoma # macOS 14+

  def install
    # zip 레이아웃에 상관없이 동작: 최상위에 AllDoc.app 이 있으면 그대로,
    # Homebrew 가 단일 디렉터리(AllDoc.app)로 자동 진입한 경우엔 현재 내용으로 재구성.
    app = Dir["**/AllDoc.app"].first
    if app
      prefix.install app
    else
      (prefix/"AllDoc.app").install Dir["*"]
    end
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
