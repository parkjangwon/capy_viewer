# Capy Viewer

![logo](/assets/images/logo.png "카피 뷰어")

Capy Viewer는 마나토끼 계열 사이트를 탐색하고 감상하기 위한 Flutter 기반 뷰어 앱입니다.  
저장소 패키지명은 `manga_view_flutter`이지만, 앱 내부와 사용자 노출 이름은 `Capy Viewer`에 가깝게 구성되어 있습니다.

## 프로젝트 개요

- Flutter 단일 코드베이스로 Android, iOS, macOS, Windows, Linux, Web 디렉터리를 모두 포함합니다.
- 실제 기능 흐름은 모바일/데스크톱 앱 사용 경험에 맞춰 설계되어 있으며, `WebView`, 로컬 DB, 파일 백업 기능 의존도가 높습니다.
- 사이트 기본 URL은 고정값만 쓰지 않고, 텔레그램 채널을 조회해 자동 갱신할 수 있도록 구현되어 있습니다.
- Cloudflare/사이트 캡챠 대응, 쿠키 동기화, 최근 본 작품 저장, 좋아요 보관, 백업/복원 같은 운영성 기능이 비교적 많이 들어가 있습니다.

## 주요 기능

- 홈
  최근 추가된 작품, 최근에 본 작품, 주간 베스트를 한 화면에서 보여줍니다.
- 검색
  제목 검색, 발행 상태, 초성, 장르 필터를 적용하고 무한 스크롤로 결과를 불러옵니다.
- 작품 상세
  작품 메타데이터와 회차 목록을 확인하고, 첫 화 보기나 회차 저장 기능을 사용할 수 있습니다.
- 뷰어
  세로 스크롤 기반으로 이미지를 감상하고 마지막 읽은 페이지를 저장합니다. 오버스크롤로 이전 화/다음 화 이동도 지원합니다.
- 최근 기록
  최근에 본 작품 목록과 마지막 페이지를 로컬 DB에 저장합니다.
- 좋아요
  좋아요한 작품을 별도 목록으로 관리합니다.
- 설정
  URL 자동/수동 모드, 시작 화면, 테마, 안심 모드, 시크릿 모드, 화면 꺼짐 방지, 캡챠 인증, 쿠키 삭제를 제공합니다.
- 백업/복원
  설정과 로컬 DB를 `.capy` 파일로 백업하고 복원할 수 있습니다.

## 기술 스택

- UI: Flutter, Material 3
- 상태 관리: `flutter_riverpod`, `riverpod_annotation`
- 네트워킹: `dio`, `http`, `dio_cookie_manager`, `cookie_jar`
- 웹 처리: `webview_flutter`, `flutter_inappwebview`, `html`
- 로컬 저장소: `shared_preferences`, `sqflite`, `path_provider`
- 이미지/뷰어: `cached_network_image`, `photo_view`
- 부가 기능: `share_plus`, `pdf`, `archive`, `file_picker`, `flutter_local_notifications`, `wakelock_plus`
- 코드 생성: `freezed`, `json_serializable`, `build_runner`, `riverpod_generator`

## 디렉터리 구조

```text
lib/
  core/                 공통 상수, 설정, 라우팅 초안, 에러 타입
  data/
    backup/             .capy 백업/복원 처리
    database/           sqflite 헬퍼
    datasources/        API, 파서, 사이트 URL 관리
    models/             freezed/json 모델
    parsers/            HTML 파싱 로직
    providers/          데이터 계층 프로바이더
    repositories/       저장소 계층 초안
  presentation/
    providers/          UI 상태 프로바이더
    screens/            홈, 검색, 상세, 뷰어, 설정 화면
    viewmodels/         화면별 비동기 로딩 로직
    widgets/            공용 위젯, 캡챠 처리 위젯
  utils/                HTML 파서, 쿠키/이미지/캡챠 유틸
test/
  widget_test.dart      기본 Flutter 샘플 테스트
.github/workflows/
  android-release.yml   태그 기반 Android APK 릴리스
```

## 앱 흐름 요약

1. 앱 시작 시 `ProviderScope` 아래에서 Riverpod 상태를 초기화합니다.
2. `MainScreen`이 하단 탭 기반으로 홈, 검색, 최근, 좋아요, 설정 화면을 전환합니다.
3. `SiteUrlService`가 현재 접속 URL을 관리하고 자동 모드면 텔레그램 채널에서 최신 주소를 찾습니다.
4. 검색/상세/뷰어 화면은 `WebView`와 `Dio` 쿠키를 동기화하면서 HTML을 읽고 직접 파싱합니다.
5. 최근 기록과 좋아요는 `sqflite`에 저장하고, 일부 설정은 `SharedPreferences`에 저장합니다.

## 로컬 저장 데이터

- `SharedPreferences`
  URL 설정, 자동 모드, 시작 화면, 테마, 안심 모드, 시크릿 모드 같은 사용자 설정을 저장합니다.
- `sqflite`
  최근 본 회차, 저장한 회차, 좋아요한 작품 정보를 저장합니다.
- `CookieJar` + WebView 쿠키
  사이트 인증 상태와 캡챠 통과 상태를 유지하는 데 사용합니다.
- `.capy` 백업 파일
  메타데이터와 데이터베이스 바이트를 묶어 백업합니다.
