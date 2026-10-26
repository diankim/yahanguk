# 야행국 夜行局

야행국 웹게임의 현재 작업 소스입니다. GitHub 저장소에 올려 Claude Code가 프런트엔드 코드를 검토하고 PC·모바일 UX/UI를 개선할 수 있도록 `index.html`로 구성했습니다.

## 현재 상태

- 현재 확보된 HTML 소스를 `index.html`로 복사했습니다.
- Supabase 연결 설정은 HTML 내부에 포함되어 있습니다. 브라우저용 publishable key만 사용해야 하며, `service_role` 키나 DB 비밀번호는 절대로 클라이언트에 넣지 마세요.
- 1차 UX/UI·안정성 개선이 반영되었습니다(아래 "변경 기록" 참고). 실제 계정 기반의 기능 테스트는 아직 수행되지 않았습니다.
- 기존 게임 기능을 분석한 뒤 수정은 별도 브랜치에서 진행하는 것을 권장합니다.

## 변경 기록 (2026-10-26)

### 프런트엔드 (`index.html`)
- 화폐 표기 치환 MutationObserver가 값이 같아도 텍스트를 재할당해 무한 루프로 페이지가 멈추던 문제 수정
- 지도 화면의 이동 시간·탐사 지점 옵저버가 DOM 변경마다 RPC를 반복 호출하던 문제 수정(디바운스·캐시·지도 영역 변경만 반응)
- 모듈별로 따로 만들던 Supabase 클라이언트(23개)를 하나로 공유 — GoTrue 다중 인스턴스 경고와 토큰 갱신 경합 제거
- 동승 요청을 `world_travel_party_invite_v2`로 호출(수락은 이미 v2 사용)
- 정의되지 않은 `notify` 호출, 제거된 로그인 탭 `click()` 오류 수정
- 중국어로 작성돼 있던 상태이상·칭호 패널을 한국어로 번역, 비로그인 시 원문 인증 오류 노출 제거
- UX 레이어(`#yahang-ux-layer`): 모바일 하단 고정 탭, 설정 메뉴 한 줄 가로 스크롤, 로그인 화면 브랜드·입력란 정리, 한국어 단어 단위 줄바꿈, 활성 탭 `aria-current`

### 백엔드 (Supabase, `supabase/migrations/`)
- `fix_idle_claim_activity_type_reference`: `world_claim_idle_activity`의 미선언 변수 `v_activity_type` 참조 수정(휴식 외 자율 활동 수령 실패)
- `transfer_party_travel_v2_step4_owner_and_narrow`: 동승 v2 함수 소유권을 전용 역할로 이전하고 권한을 필요한 컬럼 단위로 축소

## 로컬 미리보기

`index.html`을 브라우저에서 열어 정적 화면을 확인할 수 있습니다. 일부 Supabase 인증 및 데이터 기능은 브라우저 보안 정책, 인증 설정, Supabase 프로젝트 설정에 따라 로컬 파일 환경에서 정상 작동하지 않을 수 있습니다.

## 배포 전 확인

1. Supabase Auth의 허용 URL 및 리디렉션 URL 설정을 실제 배포 도메인에 맞춥니다.
2. DB의 RLS와 RPC 권한을 유지합니다. 클라이언트에서 비밀 키를 사용하지 않습니다.
3. 모바일과 PC에서 로그인, 캐릭터 상태, 이동, 전투, 거래, 파티 동승 등 주요 기능을 실제 계정으로 테스트합니다.
4. GitHub Pages 또는 Cloudflare Pages에 올리기 전에 현재 소스의 방 생성 UI, 폴링 주기, 반응형 문제를 검토합니다.

## 보안

`.env`, 서비스 역할 키, 데이터베이스 비밀번호, 개인 토큰은 이 저장소에 추가하지 마세요. 저장소는 기본적으로 Private로 만드는 것을 권장합니다.
