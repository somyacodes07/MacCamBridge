import SwiftUI

struct ContentView: View {

    @StateObject private var camera =
        CameraManager()

    var body: some View {

        VStack(
            spacing: 0
        ) {

            ZStack {

                CameraPreview(
                    session: camera.session
                )
                .frame(
                    maxWidth: .infinity
                )
                .frame(
                    height: 450
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16
                    )
                )

                if !camera.isRunning {

                    VStack(
                        spacing: 12
                    ) {

                        Image(
                            systemName:
                                "video.slash.fill"
                        )
                        .font(
                            .system(
                                size: 50
                            )
                        )

                        Text(
                            "Camera is stopped"
                        )
                        .font(
                            .headline
                        )
                    }
                }
            }
            .padding()

            Divider()

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Text(
                        "MacCam Bridge"
                    )
                    .font(
                        .title2
                    )
                    .fontWeight(
                        .bold
                    )

                    StreamStatusView(
                        server:
                            camera.streamServer
                    )
                }

                Spacer()

                if !camera.isRunning {

                    Button(
                        "Start Camera"
                    ) {

                        camera.start()
                    }
                    .buttonStyle(
                        .borderedProminent
                    )

                } else {

                    Button(
                        "Stop Camera"
                    ) {

                        camera.stop()
                    }
                    .buttonStyle(
                        .bordered
                    )
                }
            }
            .padding()
        }
        .frame(
            minWidth: 700,
            minHeight: 550
        )
    }
}

private struct StreamStatusView: View {

    @ObservedObject var server:
        StreamServer

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 3
        ) {

            if server.isRunning {

                Text(
                    "● Server running on port \(server.port)"
                )
                .foregroundStyle(
                    .green
                )

                Text(
                    "\(server.clientCount) client(s) connected"
                )
                .foregroundStyle(
                    .secondary
                )
                .font(
                    .caption
                )

            } else {

                Text(
                    "● Stream server stopped"
                )
                .foregroundStyle(
                    .red
                )
            }
        }
    }
}

#Preview {

    ContentView()
}
