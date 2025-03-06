import SwiftUI

struct NoDataView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Data Available")
                .font(.title2)
                .bold()
            Text("Start tracking your mood to see analytics")
                .foregroundColor(.gray)
        }
    }
}
struct NoDataView_Previews: PreviewProvider {
   static var previews: some View {
       NoDataView()
   }
}
