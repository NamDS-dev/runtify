---
feature: 소셜 로그인 화면 — 카카오·네이버 버튼 추가 + 순서 재배치
status: done
date: 2026-04-22
---

## Figma 프레임
| 화면 | ID | x | y |
|------|-----|---|---|
| 1-NEW. Login (Social) | 118:2 | 0 | 0 |

## 변경 요약
- 버튼 순서 재배치: **카카오 → 네이버 → Google → Apple** (기존: Apple → Google → 카카오)
- **네이버 버튼 신규 추가** (308:143 / 308:144)
- 카카오 버튼 아이콘 교체: 💛 → 💬 (공식 말풍선 로고 암시)
- 서브타이틀(118:7)을 y=340 → y=310으로 상향 이동해 4버튼 세로 공간 확보

## 레이아웃 좌표 (x, y, w, h)

### 유지되는 상단 영역
| 요소 | 노드 ID | 위치 | 변경 |
|------|---------|------|------|
| Logo BG (ellipse) | 118:3 | (159, 120, 72, 72) | 유지 |
| Logo Icon 🔥 | 118:4 | (183, 138) | 유지 |
| App Title "RUNTIFY" | 118:5 | (95, 215) | 유지 |
| Tagline | 118:6 | (95, 258) | 유지 |
| Subtitle | 118:7 | (24, 310) | y 340→310 |

### 소셜 버튼 (새 순서, 간격 16px)
| 순서 | 버튼 | 배경색 | 노드 ID | 위치 (x, y) | 텍스트 |
|------|------|--------|---------|-------------|--------|
| 1 | 카카오 | #FEE500 | 118:12 | (24, 360) | 💬  카카오로 계속하기 (#191414) |
| 2 | **네이버** | **#03C75A** | **308:143** | **(24, 432)** | **N  네이버로 계속하기 (#FFFFFF)** |
| 3 | Google | #252525 + stroke #666666 | 118:10 | (24, 504) | G  Google로 계속하기 (#FFFFFF) |
| 4 | Apple | #FFFFFF | 118:8 | (24, 576) | 🍎  Apple로 계속하기 (#0D0D0D) |

- 공통: width 342, height 56, cornerRadius 14
- 텍스트: Inter SemiBold 16pt, CENTER, width 342

### iOS 전용 배지 (Apple 버튼 우측 상단)
| 요소 | 노드 ID | 위치 |
|------|---------|------|
| iOS Badge BG | 118:19 | (300, 558, 46, 18) |
| iOS Badge Text | 118:20 | (300, 560) |

⚠️ iOS 배지가 Google 버튼(y=504~560) 끝부분과 시각적으로 살짝 겹치는 인상이 있지만, 원래 디자인 의도(Apple 버튼 외측 상단에 얹힘) 유지. 거슬리면 Apple 버튼 내측 우측(예: x=310, y=586)으로 이동 가능.

### 구분선 & Runtify 로그인 영역
| 요소 | 노드 ID | 위치 |
|------|---------|------|
| Divider Left | 118:14 | (24, 652, 140×1) |
| Divider Right | 118:15 | (226, 652, 140×1) |
| Divider Text "또는" | 118:16 | (175, 642) |
| Runtify Login Button | 118:21 | (24, 672, 342×56) |
| Runtify Login Button Text | 118:22 | (24, 690) "🔥  Runtify 계정으로 로그인" |

### 약관 (유지)
| 요소 | 노드 ID | 위치 |
|------|---------|------|
| Terms Text | 118:17 | (24, 760) |
| Terms Links | 118:18 | (24, 786) |

## 컬러 스펙
- 카카오: 배경 #FEE500, 텍스트 #191414
- **네이버: 배경 #03C75A, 텍스트 #FFFFFF (네이버 공식 그린)**
- Google: 배경 #252525, stroke #666666, 텍스트 #FFFFFF
- Apple: 배경 #FFFFFF, 텍스트 #0D0D0D
- Runtify: 배경 #1A1A1A, stroke #FF4D00 50%, 텍스트 #FF4D00

## 코딩 에이전트 참고사항

### 파일: `lib/features/auth/presentation/pages/social_login_page.dart`

1. **버튼 순서 변경**: `_buildAppleButton` → `_buildGoogleButton` → `_buildKakaoButton` 순서를 **`_buildKakaoButton` → `_buildNaverButton` → `_buildGoogleButton` → `_buildAppleButton`** 으로 재배치

2. **네이버 버튼 추가** (`_buildNaverButton`):
   - 배경 `Color(0xFF03C75A)`
   - 텍스트 "네이버로 계속하기" (흰색, w600, 15pt)
   - 로고: 흰색 'N' 22×22 (Apple/Google과 동일 패턴)
   - 탭 동작: 카카오와 동일한 "곧 만나보실 수 있어요!" SnackBar

3. **카카오/네이버 SnackBar 메시지 통일**:
   ```dart
   ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(
       content: Text('곧 만나보실 수 있어요!'),
       backgroundColor: Color(0xFF3A3A3A),
     ),
   );
   ```
   기존 "카카오 로그인은 곧 지원될 예정입니다" → 위 문구로 교체

4. **카카오 공식 로고 에셋**: Figma에는 💬 이모지로 표현했으나, Flutter 구현 시에는 `assets/images/kakao_logo.svg` (또는 `.png`) 추가해 `SvgPicture.asset` / `Image.asset`으로 교체 권장. 에셋 미확보 시 💬 유지.

5. **네이버 로고**: 간단한 'N' 텍스트(흰색 Bold 18pt)로 표현해도 무방. 공식 로고 SVG 확보 시 교체.

6. **Apple 버튼 iOS 배지**: 현재 코드에는 없음. Figma에만 존재. 플랫폼 분기 표시가 필요할 시 `Platform.isIOS` 조건부 렌더링으로 추가 가능.

### 참고 — Figma vs 현재 코드 높이 차이
- Figma: 버튼 height 56
- 현재 코드: height 54
- 코드에 맞춰 진행 또는 54→56 통일 결정 필요 (사소)
