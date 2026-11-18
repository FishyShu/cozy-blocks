import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_Music: music.checked
    property alias cfg_Volume: vol.value
    QQC2.CheckBox { id: music; Kirigami.FormData.label: "Music:"; text: "Play ~/Music/minecraft on this screen" }
    QQC2.Slider { id: vol; Kirigami.FormData.label: "Volume:"; from: 0; to: 100; stepSize: 1; enabled: music.checked }
}
