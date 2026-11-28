# GuildMaster Boss Art Pack (PR #24)

이 패키지는 PR #24의 보스 9종에 적용할 1차 전신 이미지 에셋입니다.

## 포함 내용
- 보스 9종 개별 PNG: 512x512, RGBA, 투명 배경
- `boss_manifest.json`: 보스 ID와 권장 리소스 경로
- `reference/3020_original_concept_sheet.jpg`: 사용자가 제공한 원본 컨셉 시트
- `reference/bosses_3x3_generated_sheet.png`: 개별 이미지 분리 전 생성 시트

## 보스 ID / 파일
- fenrir -> `assets/sprites/monsters/bosses/fenrir/idle.png`
- malkav -> `assets/sprites/monsters/bosses/malkav/idle.png`
- malachi -> `assets/sprites/monsters/bosses/malachi/idle.png`
- gorgon -> `assets/sprites/monsters/bosses/gorgon/idle.png`
- lilith -> `assets/sprites/monsters/bosses/lilith/idle.png`
- bone_golem -> `assets/sprites/monsters/bosses/bone_golem/idle.png`
- behemoth -> `assets/sprites/monsters/bosses/behemoth/idle.png`
- vorak -> `assets/sprites/monsters/bosses/vorak/idle.png`
- morgana -> `assets/sprites/monsters/bosses/morgana/idle.png`

## Cursor 적용 지침
1. ZIP을 프로젝트 루트에 압축 해제합니다.
2. `assets/` 폴더를 기존 프로젝트의 `assets/`에 병합합니다. 기존 파일을 덮어쓰지 말고 충돌 시 보고합니다.
3. `boss_manifest.json`의 경로를 참고해 PR #24의 실제 보스 데이터 및 렌더링 코드에서 각 ID에 대응하는 텍스처를 연결합니다.
4. 실제 파일 경로와 현재 Godot 리소스 로딩 방식을 확인한 뒤 코드 수정합니다. 경로를 추측하지 않습니다.
5. placeholder를 교체하되 전투 로직, 페이즈, 스킬, HUD, 상점/대장간은 수정하지 않습니다.
6. Fenrir부터 화면에서 크기/중심/투명 배경을 확인한 뒤 나머지 8종을 적용합니다.
7. 844x390 및 1366x768 화면 캡처를 만들고 누락된 텍스처, import 오류, 보스별 잘림을 검증합니다.

## 주의
- 이 PNG들은 보스별 기본(Idle) 이미지입니다. 공격/피격/사망 애니메이션 프레임은 포함하지 않습니다.
- 원본 컨셉 시트를 참고해 새로 정리한 1차 게임용 이미지이며, 원본의 스킬 동작 스케치는 별도 이펙트 에셋이 아닙니다.
- 투명도는 PNG 알파 채널을 사용합니다.
