import Foundation
import BusNowCore

enum PreviewBoard {
    static func approach(now: Date, scenario: PreviewScenario) -> ApproachPayload {
        switch scenario {
        case .approachEmpty:
            return ApproachPayload(fetchedAt: now, buses: [], sources: [
                SourceStatus(operatorName: .tokyu, ok: true, message: BoardCopy.approachEmpty, updatedAt: "10:30", observedAt: now),
                SourceStatus(operatorName: .kawasaki, ok: true, message: "60分以内に接近しているバスはありません。", updatedAt: "10:30", observedAt: now),
            ])
        case .approachPartial:
            return ApproachPayload(fetchedAt: now, buses: [tokyu(now: now, minutes: 3, destination: "蟹ヶ谷行き", id: "partial")], sources: [
                SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: "10:30", observedAt: now),
                SourceStatus(operatorName: .kawasaki, ok: false, message: "公式ページから取れませんでした", updatedAt: nil),
            ])
        case .approachDown:
            return ApproachPayload(fetchedAt: now, buses: [], sources: [
                SourceStatus(operatorName: .tokyu, ok: false, message: "公式ページから取れませんでした", updatedAt: nil),
                SourceStatus(operatorName: .kawasaki, ok: false, message: "公式ページから取れませんでした", updatedAt: nil),
            ])
        default:
            let soon = ApproachBus(
                id: "soon",
                operatorName: .tokyu,
                route: "溝22",
                destination: "(折)溝口南行",
                minutes: 0,
                status: "まもなく",
                observedAt: now,
                arrivesAt: now
            )
            return ApproachPayload(
                fetchedAt: now,
                buses: [soon, tokyu(now: now, minutes: 3, destination: "蟹ヶ谷行き", id: "three"), kawasaki(now: now)],
                sources: [
                    SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: "10:30", observedAt: now),
                    SourceStatus(operatorName: .kawasaki, ok: true, message: nil, updatedAt: "10:30", observedAt: now),
                ]
            )
        }
    }

    static func departures(now: Date, scenario: PreviewScenario) -> DeparturePayload {
        if scenario == .departuresDown {
            return DeparturePayload(fetchedAt: now, today: "2026-10-17", serviceFinishedToday: false, departures: [], sources: [
                SourceStatus(operatorName: .tokyu, ok: false, message: "公式ページから取れませんでした", updatedAt: nil),
                SourceStatus(operatorName: .kawasaki, ok: false, message: "公式ページから取れませんでした", updatedAt: nil),
            ])
        }
        if scenario == .departuresFinished {
            return DeparturePayload(
                fetchedAt: now,
                today: "2026-10-17",
                serviceFinishedToday: true,
                departures: [
                    departure("06:02", .tokyu, "溝22", "蟹ヶ谷行き", "2026-10-18", "平日", "明日"),
                    departure("06:08", .kawasaki, "溝21", "有馬第二団地前行き", "2026-10-18", "平日", "明日"),
                    departure("06:11", .tokyu, "溝22", "蟹ヶ谷行き", "2026-10-18", "平日", "明日"),
                ],
                sources: [
                    SourceStatus(operatorName: .tokyu, ok: true, message: nil, updatedAt: nil),
                    SourceStatus(operatorName: .kawasaki, ok: true, message: nil, updatedAt: nil),
                ]
            )
        }
        return DeparturePayload(
            fetchedAt: now,
            today: "2026-10-17",
            serviceFinishedToday: false,
            departures: [
                departure("10:41", .tokyu, "溝22", "蟹ヶ谷行き", "2026-10-17", "土曜", "今日"),
                departure("10:53", .kawasaki, "溝21", "有馬第二団地前行き", "2026-10-17", "土曜", "今日"),
                departure("11:07", .tokyu, "溝22", "蟹ヶ谷行き", "2026-10-17", "土曜", "今日"),
            ],
            sources: [
                SourceStatus(
                    operatorName: .tokyu,
                    ok: true,
                    message: TokyuTimetable.snapshotNote(revision: "2025-07-01", checkedOn: "2026-10-17", verified: false),
                    updatedAt: nil
                ),
                SourceStatus(operatorName: .kawasaki, ok: true, message: nil, updatedAt: nil),
            ]
        )
    }

    private static func tokyu(now: Date, minutes: Int, destination: String, id: String) -> ApproachBus {
        ApproachBus(
            id: id,
            operatorName: .tokyu,
            route: "溝22",
            destination: destination,
            minutes: minutes,
            status: "\(minutes)分待ち",
            observedAt: now,
            arrivesAt: now.addingTimeInterval(TimeInterval(minutes * 60))
        )
    }

    private static func kawasaki(now: Date) -> ApproachBus {
        ApproachBus(
            id: "nine",
            operatorName: .kawasaki,
            route: "溝21",
            destination: "有馬第二団地前行き",
            minutes: 9,
            status: "約9分で発車",
            observedAt: now,
            arrivesAt: now.addingTimeInterval(9 * 60)
        )
    }

    private static func departure(
        _ time: String,
        _ name: BusOperator,
        _ route: String,
        _ destination: String,
        _ date: String,
        _ day: String,
        _ when: String
    ) -> Departure {
        Departure(
            id: "\(date)-\(name.rawValue)-\(route)-\(time)",
            operatorName: name,
            route: route,
            destination: destination,
            time: time,
            date: date,
            dayLabel: day,
            whenLabel: when
        )
    }
}
