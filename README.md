# LabsSearch IconFetcher
Favicon and similar icon fetcher for iOS.

## Project background
This class is broken out of [LabsSearch] (an early attempt at coding, so the code here, too, is messy) and can theoretically be used in other projects. It will look for favicons and similar images like Apple touch icons at a provided URI.

## Dependencies
In its current state, the code asks for a **[CharacterEncoder]** struct. This exists in the [LabsSearch] project, and also exists as its own repository.

## Usage
```swift
let iconFetcher = IconFetcher()
let url = URL(string: "https://www.example.com/")!
var favIcon = UIImage()

iconFetcher.fetchIcon(for: url) { icon in
    if let icon = icon {
        DispatchQueue.main.async {
            self.favIcon.image = icon
        }
    }
}
```

## To do
Any number of improvements could be made to the code, including rewriting from scratch. In particular, network calls run completely untamed.

[LabsSearch]: https://www.github.com/cartoonchess/labssearch
[CharacterEncoder]: https://github.com/CartoonChess/labssearch-characterencoder
