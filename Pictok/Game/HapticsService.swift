import UIKit

enum HapticsService {
    static func tap()        { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func correct()    { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func wrong()      { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func solved()     { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failed()     { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
