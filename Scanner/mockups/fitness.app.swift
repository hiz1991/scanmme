
import SwiftUI

struct Progress: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                // Navigation Bar
                HStack {
                    Text("9:41 AM")
                        .font(.system(size: 11))
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "wifi")
                        Image(systemName: "battery.100")
                    }
                    .foregroundColor(.black)
                }
                .padding([.horizontal, .top])
                
                Text("Progress")
                    .font(.system(size: 26.8, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 21)
                    .padding(.top, 50)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color("gray"))
                    
                // Progress Items
                HStack(spacing: 20) {
                    ProgressItemView(color: Color("green"), label: "ABS")
                    ProgressItemView(color: Color("orange"), label: "CHEST")
                    ProgressItemView(color: Color("blue"), label: "BICEPS")
                    ProgressItemView(color: Color("purple"), label: "THIGHT")
                    ProgressItemView(color: Color("pink"), label: "SHLDRS")
                }
                .padding(.horizontal, 16)
                .padding(.top, 25)
                
                // Exercise History
                VStack(alignment: .leading) {
                    Text("EXERCISE HISTORY")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.leading, 15)
                        .padding(.top, 15)
                    
                    ExerciseChartView()
                        .padding(.top, 5)

                }
                .background(Color("lightGray").cornerRadius(15))
                .padding([.horizontal, .top], 15)
                
                // Measurements
                VStack(alignment: .leading) {
                    Text("MEASUREMENTS")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.leading, 15)
                        .padding(.top, 15)
                    
                    MeasurementChartView()
                        .padding(.top, 5)

                }
                .background(Color("lightGray").cornerRadius(15))
                .padding([.horizontal, .top], 15)
                
                Spacer()
                
                // Tab Bar
                HStack {
                    TabBarItem(systemIcon: "circles.hexagongrid.fill", text: "My Workout")
                        .foregroundColor(.gray)
                    Spacer()
                    TabBarItem(systemIcon: "chart.bar.fill", text: "Progress")
                        .foregroundColor(Color("primaryColor"))
                    Spacer()
                    TabBarItem(systemIcon: "person.circle.fill", text: "Profile")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                .background(Color.white.opacity(0.5).shadow(radius: 5))
                .frame(height: 90)
            }
        }
    }
}

struct ProgressItemView: View {
    var color: Color
    var label: String
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(color)
                    .frame(width: 40, height: 100)
                Image(systemName: "plus.app.fill")
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.black)
        }
    }
}

struct ExerciseChartView: View {
    var body: some View {
        // Placeholder for a chart
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0.0, y: geo.size.height * 0.8))
                path.addLine(to: CGPoint(x: geo.size.width * 0.2, y: geo.size.height * 0.4))
                path.addLine(to: CGPoint(x: geo.size.width * 0.4, y: geo.size.height * 0.6))
                path.addLine(to: CGPoint(x: geo.size.width * 0.6, y: geo.size.height * 0.2))
                path.addLine(to: CGPoint(x: geo.size.width * 0.8, y: geo.size.height * 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.3))
            }
            .stroke(Color.green, lineWidth: 2)
            
            HStack(spacing: 10) {
                Text("18.11")
                Text("19.11")
                Text("20.11")
                Text("21.11")
                Text("22.11")
                Text("23.11")
                Text("24.11")
            }
            .font(.system(size: 12))
            .foregroundColor(.black)
            .padding(.leading, 15)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: 140)
    }
}

struct MeasurementChartView: View {
    var body: some View {
        // Placeholder for a bar chart
        HStack {
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.green)
                    .frame(height: 60)
            }
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.green)
                    .frame(height: 120)
            }
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.green)
                    .frame(height: 30)
            }
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.green)
                    .frame(height: 80)
            }
        }
        .frame(height: 100)
        .padding(.horizontal, 15)
    }
}

struct TabBarItem: View {
    let systemIcon: String
    let text: String
    
    var body: some View {
        VStack {
            Image(systemName: systemIcon)
                .font(.system(size: 20))
            Text(text)
                .font(.system(size: 10))
        }
    }
}

struct Progress_Previews: PreviewProvider {
    static var previews: some View {
        Progress()
    }
}
