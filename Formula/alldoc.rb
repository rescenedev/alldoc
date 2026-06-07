class Alldoc < Formula
  desc "Native macOS document search & manager (name + full-text)"
  homepage "https://github.com/rescenedev/alldoc"
  url "https://github.com/rescenedev/alldoc/releases/download/v0.1.2/AllDoc.app-0.1.2.zip"
  sha256 "09892263a9f5564e0a90644f89b9682b63b77af6a9e3600efbf1c418a4e28e83"
  version "0.1.2"
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
