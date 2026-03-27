/etc/motd:
  file.managed:
    - contents: |
        {{ pillar.get('motd_message', 'Welcome') }}
        Managed by Salt + Reclass
