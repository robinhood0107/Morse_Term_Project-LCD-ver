# 📡 FPGA 모스부호 송수신기 (FPGA Morse Code Transceiver)

## Morse_Term_Project의 개선 버전입니다.
## https://github.com/dongmin173/Morse_Term_Project

## 1. 프로젝트 개요 (Overview)
본 프로젝트는 **'논리회로 및 설계'** 수업 과정에서 습득한 디지털 회로 지식을 바탕으로 설계되었습니다.  
회로도 편집기와 시뮬레이터를 이용한 설계 및 디버깅 과정을 거쳐, 최종적으로 **FPGA 보드** 상에서 동작하는 **모스부호 송수신 시스템**을 구현하는 것을 목표로 합니다.

## 2. 개발 환경 및 하드웨어 (Environment & H/W)
- **Target Board**: FPGA Development Board
- **Input**: Button Switches, DIP Switches (Keypad)
- **Output**: 7-Segment Display, Piezo Buzzer, LED
- **Key Logic**: State Machine Control, Timing Generation, Data Storage (SRAM/Register)

## 3. 모스부호 프로토콜 (Morse Code Protocol)
### 3.1 RX (수신) 측 프로토콜
- 내부적으로 **Dot=0, Dash=1** 패턴을 사용하여 모스부호를 디코딩합니다.
- 버튼 입력 시간(길이)을 직접 측정하지 않고, 사용자가 **Dot / Dash 버튼을 명시적으로 눌러서** 패턴을 만듭니다.
- 최대 4비트(4번 입력)까지 조합하여 하나의 알파벳(A~Z)으로 디코딩합니다.

### 3.2 TX (송신) 측 프로토콜
- 송신 시에는 **0.5초(Clock_Divider의 `iHalfSec` 변화 기준)마다 1비트씩 LED로 출력**합니다.
- 각 알파벳은 먼저 **Dot(0)/Dash(1) 심볼 패턴**으로 표현된 뒤, 다음 규칙에 따라 **시간 패턴**으로 확장됩니다.
- 시간 패턴 규칙
  - **Dot(단음)**: `1` (LED ON 1 tick = 0.5초)
  - **Dash(장음)**: `111` (LED ON 3 tick = 1.5초)
  - **같은 문자 안에서 Dot/Dash 사이 간격**: `0` (LED OFF 1 tick)
  - **문자 사이 간격**: `000` (LED OFF 3 tick)
- 예시 (시간 패턴 기준)
  - A (.-)    → `1 0 111 000`
  - B (-...)  → `111 0 1 0 1 0 1 000`
  - S (...)  → `1 0 1 0 1 000`
  - T (-)    → `111 000`

> RX는 버튼으로 Dot/Dash를 명시적으로 입력하고,  
> TX는 해당 패턴을 위 규칙에 따라 시간 축으로 늘려 LED에 출력합니다.

---

## 4. 주요 기능 및 동작 원리 (Features & Logic)

시스템은 **DIP Switch 1번**의 상태에 따라 송신 모드와 수신 모드로 전환됩니다.

### 📡 4.1 송신 모드 (Transmitter Mode)
**설정**: `DIP Switch 1: ON`  
선택한 알파벳들을 레지스터에 저장해 두었다가, 이를 **모스부호 시간 패턴(1/111/0/000)**으로 변환하여 LED로 송신합니다.

1. **문자 선택**
   - **KEY[1] (Button 1)**: 알파벳 순차 탐색 (`A → B → ... → Z → A`) 및 현재 선택 문자 HEX7에 표시
   - **KEY[0] (Button 0)**: 현재 선택 문자를 `A`로 리셋
2. **문자 저장 (Register, 최대 7글자)**
   - **KEY[2] (Button 2)**: 현재 선택된 알파벳을 **버퍼(최대 7글자)**에 저장
   - 저장된 내용은 HEX0~HEX6에 순서대로 표시 (HEX0: 가장 최근, HEX6: 가장 오래된)
   - 동시에, 각 알파벳에 대한 모스부호(Dot/Dash) 패턴이 **시간 패턴(1/111/0/000)**으로 변환되어 내부 `tx_buffer`에 이어 붙음
3. **버퍼 삭제 (# 기능)**
   - **KEY[4] (Button #)**: 과거에 저장해 둔 **버퍼(HEX0~HEX6)와 LED 송신용 비트 스트림(tx_buffer)을 모두 삭제**
   - 현재 선택 문자(HEX7에 보이는 글자)는 그대로 유지
4. **송신 시작**
   - **KEY[3] (Button 3)**: 버퍼에 저장된 전체 문자열을 `tx_buffer`에 누적된 시간 패턴에 따라 **0.5초 간격으로 순차 송신**
   - 송신 중에는 `tx_buffer[tx_idx]` 값에 따라 LED가 ON/OFF를 반복하며, 모든 비트를 송신하면 자동으로 정지

### 📻 4.2 수신 모드 (Receiver Mode)
**설정**: `DIP Switch 1: OFF`  
사용자가 직접 입력한 모스부호를 알파벳으로 변환하여 7-Segment에 표시합니다.

1. **모스부호 입력**
   - **KEY[1] (Button 1)**: 장음(Dash) 입력 → 스택에 `1`을 추가, 동시에 **Piezo Buzzer ON**
   - **KEY[2] (Button 2)**: 단음(Dot) 입력 → 스택에 `0`을 추가, 동시에 **Piezo Buzzer ON**
   - 버튼에서 손을 떼면 Buzzer는 OFF (버튼 길이는 중요하지 않고, **누른 횟수만 중요**)
2. **복호화 및 저장**
   - **KEY[3] (Button 3)**: 현재까지 입력된 Dot/Dash 패턴(stack)과 길이(count)를 기반으로 A~Z로 디코딩
   - 디코딩된 문자를 8문자 버퍼(shift_reg)에 저장 (HEX0~HEX7로 표시)
3. **결과 출력**
   - 7-Segment Display에는 최근 8개의 문자가 표시되며,  
     상위 모듈에서 HEX0~HEX7에 적절히 매핑되어 출력됩니다.

### 🔄 4.3 리셋 기능 (System Reset)
- **DIP Switch 3: ON**: 시스템 전체 리셋 (모든 레지스터 및 상태 초기화)


A: .- → sym_bits = 4'b0010, sym_len = 2 → 순서: 0,1
B: -... → 4'b0001, len=4 → 1,0,0,0
C: -.-. → 4'b0101, len=4 → 0,1,0,1
D: -.. → 4'b0001, len=3 → 1,0,0
E: . → 4'b0000, len=1 → 0
F: ..-. → 4'b0100, len=4 → 0,0,1,0
G: --. → 4'b0011, len=3 → 1,1,0
H: .... → 4'b0000, len=4 → 0,0,0,0
I: .. → 4'b0000, len=2 → 0,0
J: .--- → 4'b1110, len=4 → 0,1,1,1
K: -.- → 4'b0101, len=3 → 1,0,1
L: .-.. → 4'b0100, len=4 → 0,1,0,0
M: -- → 4'b0011, len=2 → 1,1
N: -. → 4'b0001, len=2 → 1,0
O: --- → 4'b0111, len=3 → 1,1,1
P: .--. → 4'b0110, len=4 → 0,1,1,0
Q: --.- → 4'b1011, len=4 → 1,1,0,1
R: .-. → 4'b0100, len=3 → 0,1,0
S: ... → 4'b0000, len=3 → 0,0,0
T: - → 4'b0001, len=1 → 1
U: ..- → 4'b0100, len=3 → 0,0,1
V: ...- → 4'b1000, len=4 → 0,0,0,1
W: .-- → 4'b0110, len=3 → 0,1,1
X: -..- → 4'b1001, len=4 → 1,0,0,1
Y: -.-- → 4'b1011, len=4 → 1,0,1,1
Z: --.. → 4'b0011, len=4 → 1,1,0,0