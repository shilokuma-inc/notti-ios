//
//  MonthDayPicker.swift
//  notti
//

import SwiftUI

/// 繰り返しが毎月のときに、鳴らす日付（1〜31 日、複数）と月末（N 日前）を選ぶ欄
///
/// 日付は 7 列の格子で、曜日には揃えない（月ごとに曜日がずれるため）
struct MonthDayPicker: View {
    @Binding var monthDays: Set<Int>
    /// 月末の何日前か（0 = 月末の当日）。月末に鳴らさないなら nil
    @Binding var monthEndOffset: Int?
    /// 1 つだけ選ぶ（完了するまで繰り返すとき）。日付を選ぶと月末を外し、月末を ON にすると日付を外す
    var selectsOne = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(MonthDay.range), id: \.self) { day in
                dayButton(day)
            }
        }
        .padding(.vertical, 4)
        Toggle("月末", isOn: isMonthEndOn)
            .accessibilityIdentifier("monthEndToggle")
        if let monthEndOffset {
            Picker("月末の何日前", selection: offsetBinding(current: monthEndOffset)) {
                ForEach(Array(MonthDay.monthEndOffsetRange), id: \.self) { offset in
                    Text(Self.offsetLabel(offset)).tag(offset)
                }
            }
            .accessibilityIdentifier("monthEndOffsetPicker")
        }
    }

    private func dayButton(_ day: Int) -> some View {
        let isSelected = monthDays.contains(day)
        return Button {
            if isSelected {
                monthDays.remove(day)
            } else if selectsOne {
                monthDays = [day]
                monthEndOffset = nil
            } else {
                monthDays.insert(day)
            }
        } label: {
            // 2 桁の日付が折り返さないよう、余白の大きい `.bordered` ではなく自前の背景にする。
            // 選んだ日の文字は背景色（アクセントの色はダークモードで白になるため、白い文字にはしない）
            Text("\(day)")
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(isSelected ? Color(.systemBackground) : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.tertiary),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day) 日")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 月末の欄の ON/OFF。ON にしたときは月末の当日から始める
    private var isMonthEndOn: Binding<Bool> {
        Binding(
            get: { monthEndOffset != nil },
            set: { isOn in
                if isOn, selectsOne {
                    monthDays = []
                }
                monthEndOffset = isOn ? (monthEndOffset ?? 0) : nil
            }
        )
    }

    private func offsetBinding(current: Int) -> Binding<Int> {
        Binding(
            get: { monthEndOffset ?? current },
            set: { monthEndOffset = $0 }
        )
    }

    /// 何日前の選択肢の表記（例: 「月末の当日」「3 日前」）
    static func offsetLabel(_ offset: Int) -> String {
        offset == 0 ? "月末の当日" : "\(offset) 日前"
    }
}

#Preview {
    @Previewable @State var monthDays: Set<Int> = [1, 15, 31]
    @Previewable @State var monthEndOffset: Int? = 3
    Form {
        MonthDayPicker(monthDays: $monthDays, monthEndOffset: $monthEndOffset)
    }
}
