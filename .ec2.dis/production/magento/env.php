<?php
return [
    'backend' => [
        'frontName' => 'admin'
    ],
    'db' => [
        'connection' => [
            'indexer' => [
                'host' => '$aws_mysql',
                'dbname' => '$dbname',
                'username' => '$username',
                'password' => '$password',
                'active' => '1',
                'persistent' => null,
                'model' => 'mysql4',
                'engine' => 'innodb',
                'initStatements' => 'SET NAMES utf8;'
            ],
            'default' => [
                'host' => '$aws_mysql',
                'dbname' => '$dbname',
                'username' => '$username',
                'password' => '$password',
                'active' => '1',
                'model' => 'mysql4',
                'engine' => 'innodb',
                'initStatements' => 'SET NAMES utf8;',
                'driver_options' => [
                    1014 => false
                ]
            ]
        ],
        'slave_connection' => [
            'default' => [
                'host' => '$aws_mysql_ro',
                'dbname' => '$db_name',
                'username' => '$username',
                'password' => '$password',
                'active' => '1',
                'model' => 'mysql4',
                'engine' => 'innodb',
                'initStatements' => 'SET NAMES utf8;',
                'driver_options' => [
                    1014 => false
                ]
            ]
        ],
        'table_prefix' => ''
    ],
    'crypt' => [
        'key' => '$crypt_key'
    ],
    'resource' => [
        'default_setup' => [
            'connection' => 'default'
        ]
    ],
    'x-frame-options' => 'SAMEORIGIN',
    'MAGE_MODE' => 'production',
    'session' => [
        'save' => 'redis',
        'redis' => [
            'host' => '$aws_redis',
            'port' => '6379',
            'password' => '',
            'timeout' => '10',
            'persistent_identifier' => '',
            'database' => '0',
            'compression_threshold' => '2048',
            'compression_library' => 'gzip',
            'log_level' => '4',
            'max_concurrency' => '100',
            'break_after_frontend' => '100',
            'break_after_adminhtml' => '30',
            'first_lifetime' => '600',
            'bot_first_lifetime' => '60',
            'bot_lifetime' => '7200',
            'disable_locking' => '1',
            'min_lifetime' => '60',
            'max_lifetime' => '2592000'
        ]
    ],
    'cache' => [
        'frontend' => [
            'default' => [
                'backend' => 'Cm_Cache_Backend_Redis',
                'backend_options' => [
                    'server' => '$aws_redis',
                    'port' => '6379',
                    'database' => '1'
                ],
                'id_prefix' => '$cache_prefix'
            ],
            'page_cache' => [
                'backend' => 'Cm_Cache_Backend_Redis',
                'backend_options' => [
                    'server' => '$aws_redis',
                    'port' => '6379',
                    'database' => '2',
                    'compress_data' => '0'
                ],
                'id_prefix' => '$cache_prefix'
            ]
        ],
        'allow_parallel_generation' => false
    ],
    'lock' => [
        'provider' => 'file',
        'config' => [
            'path' => '/var/www/html/$domain_name/var/lock'
        ]
    ],
    'cache_types' => [
        'config' => 1,
        'layout' => 1,
        'block_html' => 1,
        'collections' => 1,
        'reflection' => 1,
        'db_ddl' => 1,
        'compiled_config' => 1,
        'eav' => 1,
        'customer_notification' => 1,
        'config_integration' => 1,
        'config_integration_api' => 1,
        'full_page' => 1,
        'target_rule' => 1,
        'config_webservice' => 1,
        'translate' => 1,
        'google_product' => 1,
        'vertex' => 1
    ],
    'downloadable_domains' => [
        '$domain_name'
    ],
    'install' => [
        'date' => '$install_date'
    ],
    'system' => [
        'default' => [
            'catalog' => [
                'search' => [
                    'engine' => 'elasticsearch7',
                    'elasticsearch7_server_hostname' => '$aws_elasticsearch',
                    'elasticsearch7_server_port' => '443',
                    'elasticsearch7_index_prefix' => 'magento2'
                ]
            ],
            'system' => [
                'full_page_cache' => [
                    'caching_application' => '2'
                ]
            ]
        ]
    ],
    'queue' => [
        'amqp' => [
            'host' => '$aws_rabbitmq',
            'port' => '5671',
            'user' => '$user',
            'password' => '$password',
            'virtualhost' => '/',
            'ssl' => 'true'
        ],
        'consumers_wait_for_messages' => 0
    ],
    'cron_consumers_runner' => [
        'cron_run' => true,
        'batch-size' => 100,
        'max_messages' => 10000,
        'consumers' => [

        ]
    ],
    'http_cache_hosts' => [
        [
            'host' => '$varnish_host',
            'port' => '6081'
        ]
    ]
];
