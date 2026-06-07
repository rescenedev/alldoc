<div align="center">

# 📑 AllDoc

**macOS 네이티브 문서 검색·관리 앱**

흩어진 문서를 한곳에서 — **이름**뿐 아니라 **본문 내용**까지 즉시 검색

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI%20%2B%20AppKit-orange?logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

</div>

---

AllDoc은 PC에 흩어져 있는 문서(`hwpx`·`docx`·`pptx`·`xlsx`·`pdf`·`md`·`txt`·`csv`·`rtf` 등)를
**내가 지정한 폴더** 기준으로 모아서 탐색하고, **파일 이름과 본문 내용을 동시에** 검색하는
Finder 스타일의 네이티브 macOS 앱입니다.

## ✨ 주요 기능

- **🔍 통합 검색** — 이름·본문을 함께(또는 따로) 검색. `*.md` 같은 **글롭 패턴**도 지원
- **⚡ SQLite FTS5 전문검색** — 본문을 인덱싱해 수만 개 문서도 **즉시** 검색 (BM25 랭킹 + 스니펫)
- **📂 지정 폴더 관리** — 「전체 폴더 / 즐겨찾기 / 개별 폴더」 사이드바, 폴더 추가/제거
- **⭐ 즐겨찾기** — 자주 보는 문서를 우클릭으로 즐겨찾기, 모아보기·검색
- **👁 Quick Look** — `Space`로 미리보기, 미리보기 중 `↑/↓`로 다음/이전 문서 (Finder 동일)
- **🚀 대용량 대응** — 폴더 목록 디스크 캐싱 + 백그라운드 색인으로 3만+ 폴더도 즉시 열림
- **⌨️ 키보드 우선** — `⌘K` 검색, `Enter` 열기, `⌘O` Finder에서 위치 열기, `↑/↓` 이동

## 🧱 아키텍처

| 영역 | 기술 |
|------|------|
| UI | SwiftUI + AppKit (네이티브 통합 툴바, Quick Look) |
| 파일 탐색 | [`fd`](https://github.com/sharkdp/fd) (재귀 열거) |
| 이름 퍼지 검색 | [`fzf`](https://github.com/junegunn/fzf) (`--filter`) |
| 본문 전문검색 | **SQLite FTS5** (trigram, 내장 `libsqlite3` — 외부 의존성 없음) |
| 본문 추출 | PDFKit/`pdftotext`(pdf), `unzip`+XML(docx·pptx·xlsx·hwpx), NSAttributedString(rtf) |
| 빌드 | Swift Package Manager (Xcode 불필요) + 수동 `.app` 번들링 |

> 본문 검색은 폴더 선택 시 백그라운드로 **변경분만 증분 색인**하여 SQLite에 저장합니다.
> 한 번 색인하면 이후 검색은 인덱스 질의라 즉시 끝나며, 앱을 재시작해도 인덱스가 유지됩니다.

## 📦 설치

### Homebrew (권장)

```bash
brew install rescenedev/tap/alldoc
```

### 직접 빌드

요구 사항: macOS 14+, Swift 6 툴체인(Command Line Tools로 충분, **Xcode 불필요**), `fd`·`fzf`

```bash
brew install fd fzf poppler      # poppler → pdftotext (PDF 추출 가속)
git clone https://github.com/rescenedev/alldoc.git
cd alldoc
./build.sh release               # → build/AllDoc.app
open build/AllDoc.app
```

## ⌨️ 단축키

| 키 | 동작 |
|----|------|
| `⌘K` | 검색창으로 이동 |
| `Space` | 선택 문서 Quick Look 미리보기 |
| `↑` / `↓` | 위/아래 이동 (미리보기 열려 있으면 미리보기도 따라 이동) |
| `Enter` | 기본 앱으로 열기 |
| `⌘O` | Finder에서 파일 위치 열기 |
| 더블클릭 | 열기 · 우클릭 | 메뉴(미리보기/Finder/즐겨찾기/경로 복사) |

## 🗂 프로젝트 구조

```
Sources/AllDoc/
  Main.swift            진입점(GUI / --selftest)
  Models/               DocType · DocFile · SidebarItem
  Services/
    DocIndex.swift      SQLite FTS5 본문 인덱스
    SearchService.swift fd(목록/이름) · fzf · FTS 검색 · 증분 색인
    TextExtractor.swift 종류별 본문 추출(순수 함수)
    BrowseCache.swift   폴더 목록 디스크 캐시
    DocStore.swift      앱 상태 오케스트레이션(@MainActor)
    ProcessRunner.swift 비동기 CLI 실행
  Views/                ContentView · Sidebar · FileBrowser · Inspector · QuickLook …
build.sh                SwiftPM 빌드 + .app 번들링
Formula/alldoc.rb       Homebrew 포뮬러
docs/                   랜딩 페이지(GitHub Pages)
```

## 🛠 개발

```bash
swift build                      # 디버그 빌드
swift run AllDoc --selftest ~/Documents 검색어   # GUI 없이 검색 파이프라인 검증
```

## 📝 라이선스

MIT
