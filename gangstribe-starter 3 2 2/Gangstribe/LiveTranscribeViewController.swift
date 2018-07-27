/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import GLKit
import AVFoundation
import Speech

import MapKit
import CoreLocation

class LiveTranscribeViewController: UIViewController, CLLocationManagerDelegate {
    
    let audioEngine = AVAudioEngine()
    let speechRecognizer = SFSpeechRecognizer()
    let request = SFSpeechAudioBufferRecognitionRequest()
    var recognitionTask: SFSpeechRecognitionTask?
    
    let locationManager = CLLocationManager()
    var locationCoordinate = CLLocationCoordinate2D()
  
  @IBOutlet weak var imageView: GLKView!
  var faceReplacer: FaceReplacer!
  
  @IBOutlet weak var faceCollectionView: UICollectionView!
  let faceSource = FaceSource()
  
  @IBOutlet weak var transcriptionOutputLabel: UILabel!
  
  @IBAction func handleDoneTapped(_ sender: BorderedButton) {
    faceReplacer.stopCapture()
    stopRecording()
    if let liveString = transcriptionOutputLabel.text
    {
        let strArr = liveString.split(separator: " ")
        for item in strArr
        {
            let components = item.components(separatedBy: CharacterSet.decimalDigits.inverted)
            let part = components.joined()
            if let intVal = Int(part)
            {
                print("This is a number \(intVal)")
            }
            else
            {
                let lowerCased = item.lowercased()
                switch lowerCased
                {
                case "zero":
                    print("0")
                case "one":
                    print("1")
                case "two":
                    print("2")
                case "three":
                    print("3")
                case "four":
                    print("4")
                case "five":
                    print("5")
                case "six":
                    print("6")
                case "seven":
                    print("7")
                case "eight":
                    print("8")
                case "nine":
                    print("9")
                default:
                    print("default")
                }
            }
        }
        partsOfSpeech(for: liveString)
    }
    dismiss(animated: true, completion: .none)
  }
    
    func partsOfSpeech(for text: String)
    {
        let tagger = NSLinguisticTagger(tagSchemes: [NSLinguisticTagScheme.tokenType, .language, .lexicalClass, .nameType, .lemma], options: 0)
        let options: NSLinguisticTagger.Options = [NSLinguisticTagger.Options.omitPunctuation, NSLinguisticTagger.Options.omitWhitespace, .joinNames]
        let range = NSRange(location: 0, length: text.utf16.count)
        tagger.string = text
        if #available(iOS 11.0, *) {
            tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange, _ in
                if let tag = tag {
                    let word = (text as NSString).substring(with: tokenRange)
                    print("\(word): \(tag.rawValue)")
                    if tag.rawValue == "Number"
                    {
                        if let intVal = Int(word)
                        {
                            print("This is a number in method: \(intVal)")
                        }
                        else
                        {
                            let numberFormatter = NumberFormatter()
                            numberFormatter.locale = Locale(identifier: "en_US_POSIX")  // if you dont set locale it will use current locale so it wont detect one if the language it is not english at the devices locale
                            numberFormatter.numberStyle = .spellOut
                            let number = numberFormatter.number(from: word)
                            print("The number is \(number ?? 0)")
                        }
                    }
                    if tag.rawValue == "Noun"
                    {
                        let lowerCasedWord = word.lowercased()
                        if lowerCasedWord != "expense"
                        {
                            print("The noun is \(lowerCasedWord)")
                        }
                    }
                }
            }
        } else {
            print("Cannot be exexuted on previous versions")
            // Fallback on earlier versions
        }
    }
  
  override func viewDidLoad()
  {
        super.viewDidLoad()
    self.locationManager.requestAlwaysAuthorization()
    self.locationManager.requestWhenInUseAuthorization()
    if CLLocationManager.locationServicesEnabled() {
        locationManager.delegate = self
//        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
        initialiseFaceReplacer()
        SFSpeechRecognizer.requestAuthorization
        {
            [unowned self] (authStatus) in
            switch authStatus
            {
            case .authorized:
                do {
                    try self.startRecording()
                } catch let error {
                    print("There was a problem starting recording: \(error.localizedDescription)")
                }
            case .denied:
                print("Speech recognition authorization denied")
            case .restricted:
                print("Not available on this device")
            case .notDetermined:
                print("Not determined")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        print("locations = \(locValue.latitude) \(locValue.longitude)")
        locationCoordinate = locValue
    }
}

extension LiveTranscribeViewController {
  fileprivate func startRecording() throws {
    self.transcriptionOutputLabel.text = ""
    
    // 1
    let node = audioEngine.inputNode
    let recordingFormat = node.outputFormat(forBus: 0)
    
    // 2
    node.installTap(onBus: 0, bufferSize: 1024,
                    format: recordingFormat) { [unowned self]
                        (buffer, _) in
                        self.request.append(buffer)
    }
    
    // 3
    audioEngine.prepare()
    try audioEngine.start()
    
    recognitionTask = speechRecognizer?.recognitionTask(with: request) {
        [unowned self]
        (result, _) in
        if let transcription = result?.bestTranscription {
            self.transcriptionOutputLabel.text = transcription.formattedString
        }
    }
  }
    
    fileprivate func stopRecording() {
        audioEngine.stop()
        request.endAudio()
        recognitionTask?.cancel()
    }
}

extension LiveTranscribeViewController {
  fileprivate func initialiseFaceReplacer() {
    faceReplacer = FaceReplacer(imageView: imageView)
    do {
      try faceReplacer.startCapture()
    } catch let error as NSError {
      let alert = UIAlertController(title: "Sorry", message: error.localizedDescription, preferredStyle: .alert)
      present(alert, animated: true, completion: .none)
    }
    faceCollectionView.dataSource = faceSource
    faceCollectionView.delegate = faceSource
    faceSource.collectionView = faceCollectionView
    faceSource.faceChosen = {
      [unowned self]
      face in
      self.faceReplacer.newFace = face
    }
  }
}

