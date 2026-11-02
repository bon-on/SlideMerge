---
id: feature-retention-polish
title: Slide Merge 바다 생물 시각 개편, 슬라이드/머지 손맛, 재플레이 동기(미션, 도감, 레벨, 테마)
status: active
owner: games
related_adrs:
  - adr-slide-merge-crazygames-web
related_contracts:
  - contract-classic-mode-undo-input
  - contract-slide-merge-crazygames
  - contract-how-to-play-tutorial
required_evidence:
  - flutter-analyze
  - flutter-tests
  - flutter-web-build
  - crazygames-web-build
  - gamepix-web-build
  - harness-audit
  - layout-screenshots
---

# 기능 명세: Slide Merge 시각 개편, 손맛, 재플레이 동기

## Problem
CrazyGames가 같은 계열 게임(MergeCamp)을 "The overall quality of the game does not yet meet the expectations of our
platform"으로 거절했다. Slide Merge는 숫자가 적힌 색 사각형뿐이라 흔한 2048 클론처럼 보이고, 머지 순간의 연출이 거의 없으며,
배경음악이 없다. 판이 끝나면 최고 점수 외에 남는 것이 없어 다시 플레이할 이유(수집, 성장, 목표)가 약하다.

## Scope
1. 정체성: 진화하는 바다 생물
   - 타일 값마다 외부 에셋 없이 `CustomPainter`로 그린 귀여운 바다 생물을 보여준다. 2=Plankton, 4=Shrimp, 8=Starfish,
     16=Clownfish, 32=Pufferfish, 64=Jellyfish, 128=Crab, 256=Octopus, 512=Sea Turtle, 1024=Dolphin, 2048=Whale,
     4096=Narwhal, 8192=Sea Dragon, 16384 이상=Star Whale. 숫자는 타일 모서리의 작은 배지로만 보조 표시한다.
   - 바다 배경(물 그라데이션, 빛줄기, 거품, 해초, 모래 바닥)을 테마별로 그린다. 보드는 유리 수조 느낌의 패널이다.
   - 넓은 화면(1280x720, 1366x768 iframe, 844x390 같은 가로 화면)에서는 보드를 가운데 두고 좌우 패널에 점수/최고 점수/이동 수,
     모드와 Undo, 레벨 바, 미션, 도감/테마 버튼을 배치한다. 좁은 화면(390x844)은 위아래로 쌓는다. 어느 크기에서도 오버플로가 없다.
2. 손맛(규칙은 즉시, 연출은 뒤따름)
   - 타일은 이동 방향으로 눈에 보이게 미끄러진다. 합쳐지는 쪽 타일도 목표 칸까지 미끄러져 들어간 뒤 사라진다.
   - 머지 결과 타일은 도착 순간 이전 생물에서 새 생물로 바뀌며 튀어 오르고(pop), 거품 파티클과 "+점수" 팝업이 뜬다.
   - 한 번의 이동에서 2회 이상 머지하면 "Combo x2" 같은 배너가 뜬다.
   - 판 안에서 새 최고 타일(32 이상)을 만들면 작은 축하, 처음 보는 생물(도감 신규 = 역대 최고 타일)을 만들면 큰 축하
     (보드 전체 거품 폭발, "New creature!" 배너, 전용 효과음)를 보여준다.
   - 새로 나온 타일은 작게 시작해 튀어나온다. 빈 칸이 2칸 이하이면 보드 가장자리에 맥동하는 위험 표시를 보여준다.
   - 효과는 하나의 Ticker가 구동하고, 페인터만 다시 그린다. 연출이 진행 중이어도 다음 입력은 즉시 규칙에 반영된다.
3. 판 안의 목표: 미션
   - 판마다 미션 3개(타일 X 만들기, N번 머지, 한 번에 xN 콤보, 점수 N, N번 이동)를 제시하고 달성 시 XP 보너스를 준다.
     목표치는 모드(Classic 4x4/Relaxed 5x5)에 맞춘다. 달성한 미션은 Undo로 되돌려도 달성 상태로 남는다.
4. 판 사이의 동기
   - 결과 화면: 이동이 더 없고 Undo도 쓸 수 없을 때 보드 위에 뜬다. 점수, 모드 최고 점수, "New best!", 최고 생물, 머지 수,
     최고 콤보, 완료 미션, 획득 XP와 레벨 진행 바, 새로 열린 테마, Play again 버튼. Enter는 다시 하기, Esc는 닫기(보드 확인)이다.
     결과 화면은 보드 영역만 덮어 헤더(?, 소리, 재시작)는 그대로 쓸 수 있다.
   - 최고 점수(모드별, 기존 `best_score_<mode>` 키 유지)와 레벨을 HUD에 보여준다.
   - 도감(Album): 14종 생물을 모은다. 미발견은 실루엣과 "???"로 보인다. 시작 시 Plankton, Shrimp는 발견 상태다.
   - 레벨(XP): XP = 점수/20 + 미션 XP + 참여 보너스 10(10번 이상 이동한 판만). 레벨 L에서 다음 레벨까지 150 + 50 x (L-1) XP.
     테마 Lagoon(Lv1), Coral Reef(Lv3), Polar Sea(Lv6), Moonlit Deep(Lv10)를 연다. 테마는 꾸미기 전용이며 규칙에 영향이 없다.
     열린 테마만 고를 수 있다.
   - 재시작과 모드 전환도 진행 중인 판을 끝난 것으로 보고 XP를 반영한다(이동 0회 판은 제외). 결과 화면은 띄우지 않고 짧은
     "+N XP" 배너만 보여준다.
   - 진행도는 `shared_preferences` 키 `slide_merge_progress_v1`(JSON)에 저장한다. 손상되거나 없는 값은 기본값으로 대체하고
     플레이를 막지 않는다. 저장값을 읽기 전에는 저장하지 않으며, 그 사이의 변경은 읽은 값에 합쳐 저장한다.
5. 소리
   - 잔잔하고 방울지는(bubbly) 배경음악 루프를 `tool/generate_sounds.py`(표준 라이브러리, 결정적 출력)에 추가한다.
     16000 Hz 모노 16비트, 1 MB 이하. 웹에서는 첫 사용자 입력 후 시작, 탭이 숨겨지면 멈춘다. 사용자 소리 토글과
     CrazyGames `muteAudio`(설정 변경 리스너 포함)를 따른다. 하나의 토글이 효과음과 음악을 함께 끈다.
     iOS/Android는 네이티브 채널 `startLoop`/`stopLoop`로 반복 재생한다(iOS 인터럽션 후 재개).
   - 새 효과음: combo, discover(새 생물), mission(미션 달성), level_up(결과 화면에서 레벨 상승). 이동 한 번에는 효과음 하나만:
     game_over > discover > mission > combo > merge > slide 순으로 우선한다.
   - 이 프로젝트에는 광고 흐름이 없다(CrazyGames 빌드도 광고 없음). 광고가 생기면 광고 동안 음악을 멈춰야 한다.

## Acceptance Criteria
- 14종 생물이 모두 그림으로 그려지고, 숫자는 작은 배지로만 보인다. 16384 이상은 Star Whale로 그려진다.
- 이동 시 타일이 미끄러지고, 머지 시 pop, 파티클, 점수 팝업이 나오며 2회 이상 머지면 콤보 배너가 뜬다. 연출 중 입력은 즉시 처리된다.
- 처음 만든 생물은 큰 축하와 함께 도감에 즉시 기록되고 앱을 다시 열어도 유지된다. 미발견 생물은 실루엣이다.
- 판마다 미션 3개가 보이고, 달성 시 완료 표시와 XP가 반영된다.
- 결과 화면에 점수, 최고 점수, 신기록 여부, 최고 생물, 획득 XP와 레벨 진행이 보이고 Play again/Enter로 새 판이 시작된다.
- XP, 레벨, 선택 테마, 도감이 유지되고 손상된 저장값은 기본값으로 대체된다. 잠긴 테마는 고를 수 없다.
- 배경음악은 음소거(사용자/플랫폼) 시 멈추고, 웹에서 탭이 숨겨지면 멈췄다가 돌아오면 다시 재생된다.
- 기존 규칙(Classic/Relaxed, 스폰 확률, 점수, Undo 충전), 키보드 조작(방향키/WASD, Z/U), 튜토리얼(새 스타일),
  CrazyGames gameplayStart/Stop, GamePix 흐름, GitHub Pages 전용 결과 등록 문구는 그대로 동작한다.
- 새 오버레이(도감, 결과)가 열려 있으면 보드 입력이 막히고 Esc/Enter로 닫을 수 있다.
- 1280x720, 1366x768, 844x390, 390x844, 320x900에서 오버플로가 없다.

## Constraints
- 새 패키지 의존성 없음. 그림은 코드, 소리는 생성기로 만든다.
- lib/ 새 문자열은 영어 ASCII다. GitHub Pages 전용 결과 등록 문구(한국어)는 기존 그대로 둔다.
- `lib/game_logic.dart`의 규칙과 점수는 바꾸지 않는다. 연출용 이동 기록(`MoveReport`)만 추가한다.
- GamePix: 외부 요청 없음. 모든 자산은 번들이다.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /SlideMerge/`, `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- 임시 골든 테스트로 1280x720, 390x844, 결과 화면, 생물 그림을 PNG로 렌더링해 확인
- `node <harness-lab>/dist/index.js audit . --format md`
