# AllDoc — macOS 네이티브 문서 관리·검색 앱

Finder 스타일의 네이티브 macOS 앱으로, 흩어져 있는 문서(`hwpx`, `docx`, `pptx`,
`xlsx`, `pdf`, `md`, `txt`, `csv`, `rtf` 등)를 한곳에서 탐색하고 **이름**뿐 아니라
**본문 내용**까지 검색한다. 검색 백엔드로 `fd` / `ripgrep` / `fzf` 를 사용한다.

> SwiftUI + AppKit. Xcode 없이 **Swift Package Manager** 로 빌드하고 `.app` 으로 번들링한다.

## 주요 기능

- **Finder 같은 UI** — 사이드바(위치/종류) · 아이콘/목록 보기 · 미리보기 인스펙터 · 경로 브레드크럼 · 뒤로/앞으로/상위 이동
- **Quick Look 미리보기** — 선택한 문서를 `QLPreviewView` 로 인스펙터에 바로 렌더링
- **이름 검색** — `fd` 로 후보 수집 → `fzf` 퍼지 매칭으로 정렬
- **본문 검색** — 문서에서 평문 텍스트를 추출·캐시한 뒤 `ripgrep` 으로 검색하고, 일치한 줄(스니펫)을 보여줌
- **종류 필터 / 정렬** — 종류별 토글, 이름·수정일·크기·종류 정렬
- **실제 파일 아이콘** — `NSWorkspace` 아이콘 + 확장자 배지

### 본문 추출 방식 (종류별)

| 종류 | 추출 방법 |
|------|-----------|
| `txt` `md` `csv` `tsv` `log` | 직접 읽기(인코딩 자동 추정) |
| `pdf` | PDFKit (`PDFDocument`) → 실패 시 `pdftotext` 폴백 |
| `rtf` | `NSAttributedString` |
| `docx` `pptx` `xlsx` `hwpx` | `unzip -p` 로 내부 XML 추출 → 태그 제거 |

> 추출된 텍스트는 `~/Library/Caches/AllDoc/textcache/` 에 그림자 `.txt` 로 캐시되며,
> 원본 수정시각·크기가 바뀔 때만 재추출한다. `ripgrep` 은 이 캐시 폴더를 검색한 뒤
> 결과를 원본 문서 경로로 되돌린다.

## 요구 사항

- macOS 14+ (개발/테스트는 macOS 26 SDK)
- Swift 6.x 툴체인 (Command Line Tools 만으로 충분, **Xcode 불필요**)
- 백엔드 도구: `fd`, `ripgrep`, `fzf` (그리고 `unzip`, 선택적으로 `pdftotext`)

```bash
brew install fd ripgrep fzf poppler   # poppler → pdftotext
```

도구가 없으면 하단 상태바에 경고가 표시된다.

## 빌드 & 실행

```bash
./build.sh release      # SwiftPM 빌드 → build/AllDoc.app 생성(아이콘·서명 포함)
open build/AllDoc.app
```

개발용 디버그 빌드/실행:

```bash
swift build             # swift run 도 가능
```

## 백엔드 자체 검증 (GUI 없이)

검색 파이프라인(fd·fzf·ripgrep·추출)을 콘솔에서 바로 확인할 수 있다:

```bash
BIN="$(swift build -c release --show-bin-path)/AllDoc"
"$BIN" --selftest <검색폴더> <검색어>
# 예: "$BIN" --selftest ~/Documents 클라우드
```

## 구조

```
Sources/AllDoc/
  Main.swift              진입점(GUI / --selftest 분기)
  AllDocApp.swift         App + AppDelegate
  Models/                 DocType · DocFile · SidebarItem
  Services/
    ToolLocator.swift     fd/rg/fzf/unzip/pdftotext 경로 탐색
    ProcessRunner.swift   비동기 CLI 실행(취소·데드락 방지)
    TextExtractor.swift   종류별 본문 추출 + NFD 캐시
    XMLTextStripper.swift OOXML/HWPX XML → 평문
    FileScanner.swift     폴더 브라우징
    SearchService.swift   이름(fd+fzf) / 본문(추출+rg) 검색
    DocStore.swift        앱 상태 오케스트레이션(@MainActor)
  Views/                  ContentView · Sidebar · FileBrowser · Inspector · QuickLook …
  Utilities/              포매터 · 파일 아이콘
Tools/make_icon.swift     앱 아이콘 생성기
build.sh                  번들링 스크립트
```

## 한글 정규화 주의 (중요한 함정)

macOS 파일명은 **NFD(분해형)** 로 저장되고, 사용자가 타이핑하는 검색어는 보통
**NFC(결합형)** 이다. 게다가 Foundation `Process` 는 인자(argv)를 자식 프로세스에
넘길 때 **NFD 로 변환**한다. 이 둘이 어긋나면 한글 검색이 전부 실패한다.

AllDoc 은 **모든 검색 경로를 NFD 로 통일**해서 해결한다:

- `fzf` 후보 목록과 질의를 NFD 로 맞추고, 결과는 원본 경로로 되돌림
- `ripgrep` 질의를 NFD 로 보내고, 추출 캐시 텍스트도 NFD 로 저장

## 샘플로 테스트

`~/AllDocSample/` 에 9개 형식의 테스트 문서가 들어 있다(개발 중 생성). 앱에서
"폴더 추가…"로 이 폴더를 열고 본문 검색에 `클라우드` 를 입력하면 모든 형식이
검색된다. 필요 없으면 `rm -rf ~/AllDocSample` 로 지워도 된다.
