import Foundation

// ============================================================================
//  LIEBESBRIEFE
//  Hier stehen alle persönlichen Texte der App an einem Ort.
//  Kamran: Lies alles einmal durch und ändere, was nicht nach dir klingt.
//  Achtung: Das GitHub-Repo ist öffentlich, diese Texte sind dort lesbar.
// ============================================================================

struct LoveLetter: Identifiable {
    let id: String
    let title: String
    let body: String
    /// Ab diesem Tag ist der Brief lesbar (Jahr, Monat, Tag).
    let unlock: DateComponents

    var unlockDate: Date {
        Calendar.german.date(from: unlock) ?? .distantPast
    }

    func isOpen(on date: Date = Date()) -> Bool {
        Calendar.german.startOfDay(for: date) >= Calendar.german.startOfDay(for: unlockDate)
    }
}

enum Liebesbriefe {
    // Besondere Tage (Monat, Tag)
    static let birthday = (month: 11, day: 11)
    static let anniversary = (month: 2, day: 14)

    static let dedication = "Für die schönste Frau, die ich kenne. Egal, was du trägst, ich sehe immer nur dich."
    static let signature = "Dein Kamran"

    // Rückseite des Monogramms an der Tür
    static let monogramBack = "F + K"
    static let monogramDate = "seit einem 14. Februar"

    // Kurze Karten
    static let birthdayCard = "Alles Liebe zum Geburtstag, mein Schatz. Dieser Schrank ist für dich, und alles darin steht dir."
    static let anniversaryCard = "Happy Jahrestag. Von allen Tagen im Jahr ist das hier mein liebster."
    static let titleCard = "Mein Lieblingsoutfit an dir? Ehrlich gesagt jedes. Aber am schönsten bist du, wenn du lachst."
    static let emptyHanger = "Ich warte auf etwas Schönes."

    static let milestones: [Int: String] = [
        100: "Hundert Stücke. Und jedes sieht an dir besser aus als auf dem Bügel.",
        250: "250 Stücke. Ich glaube, wir brauchen bald einen größeren Schrank.",
        500: "500 Stücke. Du bist offiziell die stilvollste Frau, die ich kenne.",
        1000: "Tausend Stücke. Ich bin sprachlos, und sehr stolz auf dich.",
    ]

    static let goodNight: [String] = [
        "Schlaf gut, meine Schöne. Morgen suchen wir dir etwas Wunderbares aus.",
        "Gute Nacht, Fatima. Ich denke an dich.",
        "Genug ausgesucht für heute. Träum was Schönes.",
        "Das Licht geht aus, aber du leuchtest weiter. Gute Nacht.",
        "Leg das Handy weg, Schatz. Du bist morgen auch in Jogginghose die Schönste.",
    ]

    // Briefe im Geheimfach (unterste Schublade)
    static let letters: [LoveLetter] = [
        LoveLetter(
            id: "willkommen",
            title: "Für dich",
            body: """
            Meine Fatima,

            ich wollte dir etwas schenken, das es nirgendwo zu kaufen gibt. Also habe ich dir einen Schrank gebaut. Einen, der immer aufgeräumt ist, der nie zu klein wird und in dem das Licht immer perfekt ist.

            In dieser Schublade liegen Briefe von mir. Nicht alle auf einmal. Manche öffnen sich erst an besonderen Tagen. Schau ab und zu hier vorbei.

            Ich liebe dich.
            Kamran
            """,
            unlock: DateComponents(year: 2026, month: 11, day: 1)
        ),
        LoveLetter(
            id: "geburtstag-2026",
            title: "Zum Geburtstag",
            body: """
            Alles Gute zum Geburtstag, mein Schatz.

            Heute ist dein Tag, und ich hoffe, du spürst, wie sehr du geliebt wirst. Von deiner Familie, deinen Freunden und ganz besonders von mir.

            Ich wünsche dir ein Jahr voller Lachen, voller schöner Abende und voller Momente, in denen du dich in deinem Lieblingskleid wie die Königin fühlst, die du bist.

            Dein Kamran
            """,
            unlock: DateComponents(year: 2026, month: 11, day: 11)
        ),
        LoveLetter(
            id: "monat-2026-12",
            title: "Dezember",
            body: """
            Es wird kalt draußen. Das ist die perfekte Ausrede, um dich in deinen weichsten Mantel zu kuscheln, und dann zu mir.

            Ich freue mich auf jeden Winterabend mit dir.
            Kamran
            """,
            unlock: DateComponents(year: 2026, month: 12, day: 14)
        ),
        LoveLetter(
            id: "monat-2027-01",
            title: "Ein neues Jahr",
            body: """
            Neues Jahr, gleiche Liebe. Eigentlich ein bisschen mehr als letztes Jahr.

            Danke, dass du da bist.
            Kamran
            """,
            unlock: DateComponents(year: 2027, month: 1, day: 14)
        ),
        LoveLetter(
            id: "jahrestag-2027",
            title: "Zu unserem Jahrestag",
            body: """
            Meine Liebe,

            heute ist unser Tag. Alle anderen feiern Valentinstag, wir feiern uns.

            Ich weiß noch genau, wie du an diesem Tag ausgesehen hast. Und ich weiß, dass ich seitdem jeden Tag ein bisschen mehr verliebt bin.

            Danke für jedes Lachen, jede Umarmung und jede Geduld mit mir. Auf viele, viele weitere 14. Februare.

            Für immer dein
            Kamran
            """,
            unlock: DateComponents(year: 2027, month: 2, day: 14)
        ),
        LoveLetter(
            id: "monat-2027-03",
            title: "Frühling",
            body: """
            Die Mäntel dürfen langsam zurück in den Schrank. Zeit für helle Farben und lange Spaziergänge, Hand in Hand.

            Kamran
            """,
            unlock: DateComponents(year: 2027, month: 3, day: 14)
        ),
        LoveLetter(
            id: "monat-2027-04",
            title: "Kleine Erinnerung",
            body: """
            Nur damit du es nicht vergisst: Du bist wunderschön. Heute, morgen und an Tagen, an denen du es selbst nicht glaubst.

            Kamran
            """,
            unlock: DateComponents(year: 2027, month: 4, day: 14)
        ),
        LoveLetter(
            id: "monat-2027-05",
            title: "Mai",
            body: """
            Lass uns bald wieder ausgehen. Du ziehst das Kleid an, das du am liebsten magst, und ich tue so, als könnte ich mich auf das Essen konzentrieren.

            Kamran
            """,
            unlock: DateComponents(year: 2027, month: 5, day: 14)
        ),
        LoveLetter(
            id: "monat-2027-06",
            title: "Sommer",
            body: """
            Sonne, Sommerkleider und du. Mehr brauche ich nicht.

            Kamran
            """,
            unlock: DateComponents(year: 2027, month: 6, day: 14)
        ),
        LoveLetter(
            id: "monat-2027-07",
            title: "Juli",
            body: """
            Weißt du, was ich an dir am meisten liebe? Dass du die Welt ein bisschen schöner machst, einfach indem du in ihr bist.

            Kamran
            """,
            unlock: DateComponents(year: 2027, month: 7, day: 14)
        ),
        LoveLetter(
            id: "monat-2027-08",
            title: "August",
            body: """
            Falls du heute einen schlechten Tag hast: Ich bin stolz auf dich. Immer.

            Kamran
            """,
            unlock: DateComponents(year: 2027, month: 8, day: 14)
        ),
        LoveLetter(
            id: "monat-2027-09",
            title: "September",
            body: """
            Der Herbst kommt, und mit ihm deine schönsten Mäntel. Ich freue mich schon darauf, dich darin zu bewundern.

            Kamran
            """,
            unlock: DateComponents(year: 2027, month: 9, day: 14)
        ),
        LoveLetter(
            id: "monat-2027-10",
            title: "Oktober",
            body: """
            Danke für all die kleinen Dinge, die du für mich tust. Ich sehe sie alle.

            Kamran
            """,
            unlock: DateComponents(year: 2027, month: 10, day: 14)
        ),
        LoveLetter(
            id: "geburtstag-2027",
            title: "Wieder dein Geburtstag",
            body: """
            Ein Jahr ist vergangen, seit du diesen Schrank bekommen hast. Ich hoffe, er hat dir jeden Morgen ein bisschen Freude gemacht.

            Alles Liebe zum Geburtstag, Fatima. Du wirst jedes Jahr schöner, und ich jedes Jahr verliebter.

            Dein Kamran
            """,
            unlock: DateComponents(year: 2027, month: 11, day: 11)
        ),
    ]
}

enum SpecialDay {
    case birthday, anniversary

    static func today(_ date: Date = Date()) -> SpecialDay? {
        let c = Calendar.german.dateComponents([.month, .day], from: date)
        if c.month == Liebesbriefe.birthday.month && c.day == Liebesbriefe.birthday.day { return .birthday }
        if c.month == Liebesbriefe.anniversary.month && c.day == Liebesbriefe.anniversary.day { return .anniversary }
        return nil
    }

    var card: String {
        switch self {
        case .birthday: return Liebesbriefe.birthdayCard
        case .anniversary: return Liebesbriefe.anniversaryCard
        }
    }

    var cardTitle: String {
        switch self {
        case .birthday: return "Alles Liebe"
        case .anniversary: return "Unser Tag"
        }
    }
}
