import UIKit

class FoodDetailsViewController: UIViewController {
    
    var foodName: String?
    var calories: Double?
    var additionalDetails: String?
    
    @IBOutlet weak var foodNameLabel: UILabel!
    @IBOutlet weak var caloriesLabel: UILabel!
    @IBOutlet weak var additionalDetailsLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        foodNameLabel.text = foodName
        caloriesLabel.text = "Calories: \(calories ?? 0) kcal"
        additionalDetailsLabel.text = additionalDetails
    }
}
