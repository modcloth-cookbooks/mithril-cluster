name             'mithril-cluster'
maintainer       'ModCloth, Inc.'
maintainer_email 'external.tools+mithril-cluster-cookbook@modcloth.com'
license          'Apache v2.0'
description      'Installs/Configures mithril-cluster'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.2.0'

supports 'ubuntu'

suggests 'golang'
suggests 'modcloth-stingray-exec'
suggests 'travis-buddy'
