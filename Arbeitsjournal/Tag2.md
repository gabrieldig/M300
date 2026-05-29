# Tag 2

Heute stand die Integration von Ansible auf dem Plan, um die Konfiguration der K3s-Cluster zu automatisieren.

Nach vielen Fehlläufen und Debugging-Sessions konnte ich schließlich die Ansible-Playbooks erfolgreich ausführen, um die K3s-Master- und Worker-Nodes zu konfigurieren.

Ich musste schlussendlich auch noch Github in meine Arbeitsumgebung integrieren, um die Playbooks auf die Server zu bekommen.

# Pros
- Ansible ist super für die Automatisierung, da es Agentless funktioniert und ich keine zusätzlichen Software auf den Nodes installieren muss.
- Ich habe für eine bessere Übersicht meine grosse Terrraform Datei in kleine Playbooks aufgeteilt, was die Wartbarkeit und Übersicht deutlich verbessert hat.

# Cons
- Die Fehlersuche bei Ansible war teilweise sehr zeitaufwendig, da die Fehlermeldungen nicht immer eindeutig waren.
- Die Integration von Github hat mich auch einige Zeit gekostet, da ich nicht genau wusste, wie ich die Playbooks am besten auf die Server bekomme.
- Bei jeder änderung der Playbooks musste ich die Änderungen immer erst in Github pushen, bevor ich sie auf den Servern ausführen konnte.
- SSH Berechtigungen waren auch ein Problem, da ich sicherstellen musste, dass die Ansible-Playbooks die richtigen Berechtigungen haben, um auf die Server zuzugreifen und die Konfiguration durchzuführen.

# Nächste Schritte
- Vielleicht das ausführen der Ansibleplaybooks mit Terraform automatisieren, damit ich nicht jedesmal manuell die Playbooks ausführen muss, sondern das Terraform das automatisch macht, nachdem die Infrastruktur aufgebaut wurde.
- Anfangen die 

> Vorheriger Tag -> [Tag 1](./Tag1.md)
