import UIKit

final class LegalViewController: UIViewController {
    private let document: LegalDocument

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = document.subtitle
        return label
    }()

    private lazy var textView: UITextView = {
        let view = UITextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = GamePalette.deepNavy.withAlphaComponent(0.4)
        view.layer.cornerRadius = 16
        view.textContainerInset = UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        view.textColor = .white
        view.tintColor = GamePalette.cyan
        view.isEditable = false
        view.alwaysBounceVertical = true
        view.adjustsFontForContentSizeCategory = true
        view.attributedText = makeAttributedText()
        view.accessibilityLabel = document.title
        return view
    }()

    init(document: LegalDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
        title = document.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GamePalette.deepNavy
        view.addSubview(subtitleLabel)
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            subtitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            textView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func makeAttributedText() -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = 12

        let introAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]

        attributed.append(NSAttributedString(string: document.introduction + "\n\n", attributes: introAttributes))

        let headingParagraph = NSMutableParagraphStyle()
        headingParagraph.lineSpacing = 2
        headingParagraph.paragraphSpacing = 6

        for section in document.sections {
            let headingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .headline),
                .foregroundColor: GamePalette.solarGold,
                .paragraphStyle: headingParagraph
            ]
            attributed.append(NSAttributedString(string: section.title + "\n", attributes: headingAttributes))

            attributed.append(NSAttributedString(string: section.body + "\n\n", attributes: introAttributes))
        }

        return attributed
    }

    @objc
    private func dismissSelf() {
        dismiss(animated: true)
    }
}
