import 'package:flutter/material.dart';

// 이용약관 전문 페이지
// MVP 단계 간이 약관. 출시 직전 법무 검토 후 docs/TERMS_OF_SERVICE.md 로 마스터 이관 예정.
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  static const String _body = '''
# Runtify 이용약관

**시행일:** 2026년 4월 24일

## 제1조 (목적)
본 약관은 Runtify(이하 "서비스")를 이용함에 있어 서비스와 이용자 간의 권리, 의무 및 책임 사항을 규정함을 목적으로 합니다.

## 제2조 (용어의 정의)
1. **이용자**: 본 서비스에 가입해 약관에 따라 서비스를 이용하는 회원.
2. **러닝 데이터**: 이용자가 서비스 내에서 생성하는 GPS 경로, 거리, 시간, 페이스 등의 기록.
3. **크루**: 서비스 내 그룹 기능을 통해 결성되는 이용자 모임.

## 제3조 (회원가입)
1. 회원가입은 이용약관과 개인정보처리방침에 동의한 이용자에 한해 진행됩니다.
2. 회원은 이메일 + 비밀번호 또는 소셜 로그인(Google, Apple 등)으로 가입할 수 있습니다.
3. 만 14세 미만의 이용자는 회원가입이 제한될 수 있습니다.

## 제4조 (서비스의 제공)
1. 서비스는 러닝 트래킹, 크루/랭킹 시스템, 포인트·배지 시스템 등을 제공합니다.
2. 서비스는 기술적 문제, 유지보수 등의 사유로 일시 중단될 수 있습니다.
3. 서비스 내용은 운영상 필요에 따라 변경될 수 있으며, 주요 변경은 앱 내 공지로 안내합니다.

## 제5조 (이용자의 의무)
1. 이용자는 다음 행위를 하여서는 안 됩니다.
   - 타인의 계정 무단 도용
   - GPS 조작, 자동화 도구 사용 등 러닝 데이터 위·변조
   - 크루·랭킹 시스템의 부정 이용
   - 타인에 대한 비방·명예훼손 등 공서양속에 반하는 행위
2. 위 의무를 위반한 경우 서비스 이용이 제한될 수 있습니다.

## 제6조 (계정 탈퇴)
1. 이용자는 언제든지 앱 내 "계정 삭제" 기능을 통해 탈퇴할 수 있습니다.
2. 탈퇴 시 개인정보 처리는 별도의 개인정보처리방침에 따릅니다.

## 제7조 (면책 조항)
1. 러닝 중 발생한 부상·사고·재산 피해에 대해 서비스는 법적 책임을 지지 않습니다.
2. 불가항력적 사유(천재지변, 통신장애 등)로 인한 서비스 중단에 대한 책임은 면제됩니다.

## 제8조 (문의)
- 이메일: runtify.dev@gmail.com
- 서비스명: Runtify

---

본 약관은 MVP 단계의 간이본이며, 정식 출시 전 법무 검토 후 갱신될 예정입니다.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이용약관')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Text(
            _body,
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
      ),
    );
  }
}
