import SwiftUI

/// 앱 전체에서 쓰는 단일 슬레이트 팔레트. 모든 패널·툴바·구분선을 한 톤으로 통일한다.
extension Color {
    /// 기본 배경(슬레이트). 모든 패널·툴바·상태바에 동일 적용.
    static let appBG = Color(red: 0.118, green: 0.145, blue: 0.188)      // ~#1e2530
    /// 살짝 밝은 슬레이트. 검색창·섹션 카드·선택 폴더 등 약한 강조.
    static let appElevated = Color(red: 0.165, green: 0.196, blue: 0.243) // ~#2a323e
    /// 구분선.
    static let appLine = Color(red: 0.235, green: 0.267, blue: 0.318)    // ~#3c4451
}
