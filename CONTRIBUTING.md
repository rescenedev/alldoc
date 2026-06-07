# 기여 가이드 (Contributing to AllDoc)

AllDoc 에 관심 가져주셔서 감사합니다. 버그 리포트, 기능 제안, 코드 기여 모두 환영합니다.

## 시작하기

### 요구 사항

- macOS 14 (Sonoma) 이상
- Swift 5.9+ (Xcode Command Line Tools)
- 백엔드 도구: [`fd`](https://github.com/sharkdp/fd), [`fzf`](https://github.com/junegunn/fzf), `poppler`(pdftotext)

```bash
brew install fd fzf poppler
```

### 빌드 & 실행

```bash
git clone https://github.com/rescenedev/alldoc.git
cd alldoc
swift build -c release      # SwiftPM 빌드
./build.sh release          # .app 번들 생성
open build/AllDoc.app
```

### 셀프테스트(GUI 없이 인덱싱·검색 검증)

```bash
swift run AllDoc --selftest <폴더경로> <검색어>
```

### 단위 테스트

XCTest 기반 단위·통합 테스트가 `Tests/AllDocTests/` 에 있습니다(인덱스/검색/추출/정렬/하이라이트 등).

```bash
swift test
```

> XCTest 는 전체 Xcode 에 포함됩니다. `xcode-select` 가 CommandLineTools 를 가리키면
> 다음처럼 Xcode 툴체인을 지정해 실행하세요.
>
> ```bash
> DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
> ```

## 프로젝트 구조

```
Sources/AllDoc/
├─ Main.swift            # 진입점(--selftest CLI / GUI)
├─ AllDocApp.swift       # @main, 윈도/툴바/단축키
├─ Services/             # DocIndex(SQLite FTS5), SearchService, TextExtractor, FolderWatcher …
├─ Views/                # SwiftUI 뷰(ContentView, FileBrowserView, InspectorView, *Preview …)
└─ Utilities/            # Theme, Highlighter, Formatters, 캐시 …
```

## 코딩 규칙

- **작은 파일 다수 > 큰 파일 소수.** 파일당 200~400줄을 권장, 800줄을 넘기지 않습니다.
- **불변성 우선.** 기존 객체를 변형하지 말고 새 값을 만들어 반환합니다.
- 사용자 입력·외부 데이터(파일 내용, 프로세스 출력)는 **경계에서 검증**합니다.
- 에러는 삼키지 말고 명시적으로 처리합니다.
- 한국어 UI 문자열·주석을 유지합니다(이 앱의 1차 사용자층).
- **레이아웃/헤더 구조는 함부로 바꾸지 않습니다.** 통합 툴바는 한 줄을 유지해야 합니다.

## 커밋 메시지

[Conventional Commits](https://www.conventionalcommits.org/) 형식을 따릅니다.

```
<type>: <설명>

type: feat | fix | refactor | docs | test | chore | perf | ci | style
```

## Pull Request

1. 브랜치를 만들어 작업합니다 (`feat/...`, `fix/...`).
2. 변경 사항을 빌드로 검증합니다 (`swift build -c release`, `./build.sh release`).
3. PR 본문에 **무엇을 / 왜 / 어떻게 테스트했는지**를 적습니다.
4. UI 변경이면 스크린샷(또는 GIF)을 첨부합니다.

## 버그 리포트

[이슈](https://github.com/rescenedev/alldoc/issues)에 다음을 포함해 주세요.

- macOS 버전, AllDoc 버전
- 재현 단계 / 기대 결과 / 실제 결과
- 가능하면 스크린샷과 콘솔 로그

## 보안 취약점

공개 이슈가 아닌 [SECURITY.md](./SECURITY.md) 절차를 따라 비공개로 제보해 주세요.

## 라이선스

기여하신 코드는 프로젝트와 동일하게 [MIT 라이선스](./LICENSE) 하에 배포됩니다.
