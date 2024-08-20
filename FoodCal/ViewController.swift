import UIKit
import ARKit
import CoreML
import SceneKit

class ViewController: UIViewController, ARSessionDelegate {
    
    var selectedFoodDetails: (name: String, calories: Double, additionalDetails: String)?
    @IBOutlet var arView: ARSCNView!
    var model: FoodRecognizer_!
    var predictionTextNode: SCNNode?
    @IBOutlet weak var allDetailsButton: UIButton!
    
    @IBAction func allDetailsButtonPressed(_ sender: UIButton) {
        performSegue(withIdentifier: "showFoodDetails", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "showFoodDetails" {
                if let destinationVC = segue.destination as? FoodDetailsViewController {
                    // Pass the selected food details to the destination view controller
                    if let details = selectedFoodDetails {
                        destinationVC.foodName = details.name
                        destinationVC.calories = details.calories
                        destinationVC.additionalDetails = details.additionalDetails
                    }
                }
            }
        }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self
        
        // Load the Core ML model
        do {
            model = try FoodRecognizer_(configuration: MLModelConfiguration())
        } catch {
            fatalError("Failed to load Core ML model: \(error)")
        }
        
        // Start the AR session
        let configuration = ARWorldTrackingConfiguration()
        arView.session.run(configuration)

        
        // Add a tap gesture recognizer
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        // Get the tap location in the view
        let tapLocation = gesture.location(in: arView)
        
        // Perform a hit test to find real-world surfaces
        let hitTestResults = arView.hitTest(tapLocation, types: [.featurePoint, .existingPlaneUsingExtent])
        
        // Check if we have at least one result
        if let hitResult = hitTestResults.first {
            // Get the current ARFrame
            guard let currentFrame = arView.session.currentFrame else { return }
            let pixelBuffer = currentFrame.capturedImage
            
            // Make a prediction when the screen is tapped
            if let (prediction, probability) = makePrediction(from: pixelBuffer), probability > 0.7 {
                // Handle the prediction results
                print("pred \(prediction) prob \(probability)")
                let text = "Prediction: \(prediction)\nProbability: \(Int(probability * 100))%"
                updatePredictionText(text, atPosition: hitResult.worldTransform)
                let formattedPrediction = prediction.replacingOccurrences(of: "_", with: " ")
                makeAPICall(food: formattedPrediction) { calories in
                    if let calories = calories {
                        print("Calories from API: \(calories)")
                        self.updatePredictionText(text + "\nColaries:\(calories)/100gr", atPosition: hitResult.worldTransform)
                        self.selectedFoodDetails = (name: formattedPrediction, calories: calories, additionalDetails: "More details about \(formattedPrediction).")
                    } else {
                        print("Failed to get calories.")
                    }
                }
            }
        }
        
    }
    func makeAPICall(food: String, completion: @escaping (Double?) -> Void) {
        let query = food.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://api.calorieninjas.com/v1/nutrition?query=" + query)!
        var request = URLRequest(url: url)
        request.setValue("qB7SgmUJtCj4ShtX2RlQxw==7jzmtY5La6MHH8FE", forHTTPHeaderField: "X-Api-Key")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let items = json["items"] as? [[String: Any]],
                   let firstItem = items.first,
                   let calories = firstItem["calories"] as? Double {
                    completion(calories)
                } else {
                    completion(nil)
                }
            } catch {
                print("Error parsing JSON: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
    
    
    
    func makePrediction(from pixelBuffer: CVPixelBuffer) -> (String, Double)? {
        do {
            let input = FoodRecognizer_Input(image: pixelBuffer)
            
            let prediction = try model.prediction(input: input)
            let probabilities = prediction.targetProbability
            
            // Find the label with the highest probability
            if let (bestLabel, bestProbability) = probabilities.max(by: { $0.value < $1.value }) {
                return (bestLabel, bestProbability)
            }
            
            return nil
        } catch {
            print("Error making prediction: \(error)")
            return nil
        }
    }
    
    func updatePredictionText(_ text: String, atPosition transform: matrix_float4x4) {
        // Remove the old text node if it exists
        predictionTextNode?.removeFromParentNode()
        
        // Create a new text node
        let textGeometry = SCNText(string: text, extrusionDepth: 1.0)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.green
        let textNode = SCNNode(geometry: textGeometry)
        
        // Convert the matrix_float4x4 to SCNVector3
        let position = SCNVector3(
            transform.columns.3.x - 0.05,
            transform.columns.3.y,
            transform.columns.3.z
        )
        textNode.position = position
        textNode.scale = SCNVector3(0.001, 0.001, 0.001) // Scale the text node
        
        // Add the text node to the scene
        arView.scene.rootNode.addChildNode(textNode)
        predictionTextNode = textNode
    }
    
    func preprocessImage(_ image: UIImage) -> UIImage? {
        let imageSize = CGSize(width: 224, height: 224) // Change to your model's expected size
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 2.0)
        image.draw(in: CGRect(origin: .zero, size: imageSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
}

// UIImage extension to create UIImage from CVPixelBuffer
extension UIImage {
    convenience init?(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        self.init(cgImage: cgImage)
    }
}
