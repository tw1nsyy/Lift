import SwiftUI

/// The research behind the progression rules used in LIFT.
struct ScienceView: View {
    private struct Source: Identifiable {
        let id = UUID()
        let citation: String
        let finding: String
        let usage: String
    }

    private var sources: [Source] {
        [
            Source(citation: "American College of Sports Medicine. Progression models in resistance training for healthy adults. Med Sci Sports Exerc. 2009;41(3):687–708.",
                   finding: tr("When training at a specific load, increase it by 2–10% once you can do the current workload for one to two reps over the desired number. For muscle growth the emphasis is on the 6–12 RM zone with higher-volume, multiple-set programs."),
                   usage: tr("LIFT's 2-for-2 rule is a conservative version of this guidance: it holds the weight until you do 2+ reps over target in two sessions in a row, then adds 2.5% (upper body) or 5% (legs), inside the 2–10% range.")),
            Source(citation: "Schoenfeld BJ, Ogborn D, Krieger JW. Dose-response relationship between weekly resistance training volume and increases in muscle mass: a systematic review and meta-analysis. J Sports Sci. 2017;35(11):1073–1082.",
                   finding: tr("Across 15 studies, higher weekly training volume gave greater muscle growth, in a graded way. The highest category analysed was 10 or more weekly sets per muscle."),
                   usage: tr("Plan enough hard sets for each muscle across the week. In Programs you choose the number of sets for every exercise.")),
            Source(citation: "Schoenfeld BJ, Grgic J, Ogborn D, Krieger JW. Strength and hypertrophy adaptations between low- vs. high-load resistance training: a systematic review and meta-analysis. J Strength Cond Res. 2017;31(12):3508–3523.",
                   finding: tr("Heavy loads gave greater gains in maximal (1RM) strength, while muscle growth was similar across a wide range of loads when sets were taken to failure."),
                   usage: tr("Choose lower reps with heavier weights for strength and moderate ranges for muscle. Every exercise in a program has its own rep range.")),
            Source(citation: "Zourdos MC, et al. Novel resistance training-specific rating of perceived exertion scale measuring repetitions in reserve. J Strength Cond Res. 2016;30(1):267–275.\nHelms ER, et al. Application of the repetitions in reserve-based rating of perceived exertion scale for resistance training. Strength Cond J. 2016;38(4):42–49.",
                   finding: tr("A rating scale based on repetitions in reserve (RIR) is a practical way to regulate daily training load. A follow-up article explains how to build RIR targets into a plan."),
                   usage: tr("In the “% of 1RM with reserve reps” model, LIFT calculates the working weight for your target reps and keeps a chosen number of reps in reserve (default 2).")),
            Source(citation: "Epley B. Poundage chart. Boyd Epley Workout. University of Nebraska, 1985.",
                   finding: tr("The Epley formula estimates a one-rep max as weight × (1 + reps ÷ 30). It is an estimate that becomes less accurate as reps increase."),
                   usage: tr("All 1RM numbers in LIFT are estimates by this formula unless you enter your own tested max."))
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(tr("LIFT's progression rules are based on published research. They are general guidance, not medical advice, and individual response varies. If you have an injury or a medical condition, ask a qualified coach or doctor."))
                    .font(.lift(13, .medium)).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(sources) { s in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(s.citation)
                            .font(.lift(13, .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        label(tr("What it says"), s.finding)
                        label(tr("How LIFT uses it"), s.usage, tint: Theme.accent)
                    }
                    .card()
                }

                Text(tr("Double progression is a widely used coaching method rather than a specific study; it follows the same principle as the ACSM guidance."))
                    .font(.lift(11, .medium)).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .screenBackground()
        .tabBarClearance()
        .navigationTitle(tr("Scientific basis"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func label(_ title: String, _ text: String, tint: Color = Theme.textSecondary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.lift(11, .bold)).textCase(.uppercase).foregroundStyle(tint)
            Text(text).font(.lift(14, .medium)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
