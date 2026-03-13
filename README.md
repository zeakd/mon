# Mon

macOS 메뉴바에서 에이전트/작업 세션을 모니터링하는 도구.

터미널 탭을 왔다갔다 하며 상태를 확인하는 대신, 메뉴바의 잉크 애니메이션으로 한눈에 파악한다.

## 구조

```
Mon
├── MonitorKit        공유 라이브러리 (Session, SessionStore)
├── mon               CLI — 세션 등록/ping/종료
└── MonitorApp        메뉴바 앱 — 세션 표시 + 잉크 애니메이션
```

- **CLI** (`mon`): 세션 lifecycle 관리. hook이나 스크립트에서 호출한다.
- **메뉴바 앱** (`MonApp`): SQLite를 polling하여 세션 상태를 표시한다.
- **MonitorKit**: 둘 다 공유하는 `Session` 모델과 `SessionStore` (SQLite).

데이터는 `~/.mon/sessions.db`에 저장된다. CLI와 앱이 같은 DB를 공유한다.

## 빌드 & 설치

```bash
# 빌드
./scripts/build.sh

# CLI 설치
ln -sf .build/arm64-apple-macosx/release/mon /usr/local/bin/mon

# 앱 설치
cp -r .build/Mon.app /Applications/
```

요구사항: macOS 14+, Swift 5.9+

## CLI 사용법

```bash
# 세션 시작 — ID를 stdout으로 출력
SESSION_ID=$(mon start "my-task")

# 하트비트 — 주기적으로 호출하여 active 유지
mon ping $SESSION_ID

# 세션 종료
mon end $SESSION_ID

# 세션 목록
mon ls

# 24시간 지난 세션 정리
mon prune
```

### 포커스 (--focus)

세션 클릭 시 해당 터미널로 포커스하는 기능.

```bash
# 자동 감지 — tmux/iTerm2/Terminal.app 환경을 자동으로 판별
mon start "task" --focus auto

# 수동 지정
mon start "task" --focus "tmux select-pane -t %3"
```

자동 감지 우선순위:
1. **tmux** — `TMUX_PANE` 환경변수로 정확한 pane 포커스
2. **iTerm2** — `ITERM_SESSION_ID`로 특정 탭 포커스 (AppleScript)
3. **Terminal.app** — tty 경로로 특정 탭 포커스 (AppleScript)

## 메뉴바 앱

- **잉크 방울 애니메이션**: 세션마다 잉크 방울 하나. active면 숨쉬듯 움직이고, idle이면 깜빡인다.
- **왼클릭**: 세션 리스트 popover. 클릭하면 해당 터미널로 포커스.
- **우클릭**: Settings / Quit 메뉴.

### 상태 판정

- **Active** (● 초록): 마지막 ping으로부터 idle timeout(기본 30초) 이내
- **Idle** (○ 회색): timeout 초과. 세션은 남아있지만 응답 없음

### 설정 (Settings)

- **Breath**: 숨쉬기 애니메이션 속도
- **Amplitude**: 숨쉬기 진폭
- **Drift**: 방울 표류 속도
- **Spread**: 방울 성장 속도
- **Idle after**: idle 판정 timeout (초)

## 연동 예시

### Claude Code hook

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "",
      "hooks": ["mon ping $MON_SESSION_ID"]
    }]
  }
}
```

### 스크립트 래퍼

```bash
#!/bin/bash
SESSION_ID=$(mon start "$1" --focus auto)
trap "mon end $SESSION_ID" EXIT

# 주기적 ping을 백그라운드로
(while true; do mon ping $SESSION_ID; sleep 10; done) &
PING_PID=$!
trap "kill $PING_PID 2>/dev/null; mon end $SESSION_ID" EXIT

# 실제 작업
"$@"
```

## 아키텍처 노트

### 왜 SQLite인가

CLI와 앱 사이 통신이 필요하다. 서버를 띄우는 대신 SQLite WAL 모드로 파일 공유한다.
- 프로세스 간 동기화 불필요
- 앱이 꺼져있어도 CLI는 정상 동작
- 네트워크 불필요 (로컬 전용)

### 잉크 애니메이션

메뉴바 아이콘을 픽셀 단위로 직접 렌더링한다.
- Retina: 72×20px (36×10pt), 4단계 알파
- Non-retina: 36×10px, 3단계 알파
- 10fps, `NSImage.isTemplate = true`로 다크/라이트 모드 자동 대응
- 유기적 윤곽: 3주파수 사인파 중첩 노이즈

### 향후 계획

- Tailscale 위 셀프호스트 서버 (원격 머신 세션 통합)
- 4상태 모델 도입 (running / waiting / done / error)
- 범용 모니터링 대상 확장 (Claude Code + 봇 + 모든 작업)

## 요구사항

- macOS 14.0+
- Swift 5.9+
- 외부 의존성 없음

## 라이선스

MIT
