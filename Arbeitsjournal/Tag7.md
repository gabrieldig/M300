# Tag 7

Heute habe ich mich um das Problem, das Ansible nicht korrekt das ansible.cfg File verwendet. Da es zu begin funktioniert hat, war ich zuerst ein bisschen verwirrt, bis ich auf die Lösung gekommen bin.

Zu begin, bin ich von hand in das Verzeichnis von Ansible gegangen, in dem alle meine Scritps und weiteres lagen. Dort war auch das ansible.cfg. Jedoch mittlerweile habe ich ein Command in den Output von Terraform hinzugefügt, denn mich von überall aus das Playbook ausführen lässt.
Das führt dazu, das ich nicht mehr im gleichen Verzeichnis bin, wie das ansible.cfg, und deshalb greift Ansible auch nicht die korrekten Konfigurationen die darin stehen. Ich wollte mit dem mir ein bisschen Zeit sparren, jedoch sehe ich jetzt, das ich dabei keine Zeit sparren kann.

(Zumindest denke ich es)


