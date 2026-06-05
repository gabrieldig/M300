# Tag 3
Heute habe ich ein bisschen mit Host-Fingerpritns gekämpft, da Ansible jedesmal Fragt, ob ich den Fingerprint akzeptieren möchte, wenn ich das Playbook ausführe. Das ist natürlich nicht ideal, da es den Automatisierungsprozess unterbricht.

Letzte Woche hat das noch mit dem ``host_key_checking= False`` funktioniert, aber jetzt scheint es, als ob der Parameter nicht mehr funktioniert.

Schlussendlich habe ich keine Lösung dafür gefunden, und ich werde mich in Zukunft zu begin, nach dem Deploy der Infrastruktur, manuell auf die Nodes verbinden und die Fingerprints akzeptieren, damit Ansible dann ohne Probleme die Playbooks ausführen kann.

Als nächstes habe ich mich mit dem Planen vom einfügen von Monitoring Tools wie Prometheus und Grafana beschäftigt, um die Performance und den Zustand des Clusters besser überwachen zu können.

# Pros
- Man kann das Hostproblem zu glück umgehen

# Cons
- Das Hostproblem ist natürlich nicht ideal, da es den Automatisierungsprozess unterbricht und manuelle Eingriffe erfordert.

# Nächste Schritte
- Manuell die Fingerprints akzeptieren, damit Ansible die Playbooks ausführen kann.
- Planen vom einfügen von Monitoring Tools wie Prometheus und Grafana, um die Performance und den Zustand des Clusters besser überwachen zu können.

> Vorheriger Tag -> [Tag 2](./Tag2.md)
> Nächster Tag -> [Tag 4](./Tag4.md)