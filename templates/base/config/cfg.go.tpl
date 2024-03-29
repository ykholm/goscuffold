package config

import (
	"io/ioutil"

	"github.com/go-ozzo/ozzo-validation"
	"github.com/lancer-kit/armory/log"
	"github.com/lancer-kit/uwe/v2"
	{{if .api}}
	"github.com/lancer-kit/uwe/v2/presets/api"
	{{end}}
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v2"
)

const ServiceName = "service-scaffold"

// Cfg main structure of the app configuration.
type Cfg struct {
    {{if .api}}
	Api     api.Config   `json:"api" yaml:"api"`
	{{end}}

	{{if .db}}
	DB      DBCfg        `json:"db" yaml:"db"`           // DB is a database connection string.
	{{end}}
	Log     log.Config   `json:"log" yaml:"log"`

	DevMode             bool `json:"dev_mode" yaml:"dev_mode"`
	ServicesInitTimeout int  `json:"servicesInitTimeout" yaml:"services_init_timeout"`

	// Workers is a list of workers
	// that must be started, start all if empty.
	Workers []uwe.WorkerName `yaml:"workers"`
}

func (cfg Cfg) Validate() error {
	return validation.ValidateStruct(&cfg,
	    {{if .db}}
		validation.Field(&cfg.DB, validation.Required),
		{{end}}

		{{if .api}}
		validation.Field(&cfg.Api, validation.Required),
		{{end}}

		validation.Field(&cfg.ServicesInitTimeout, validation.Required),
		validation.Field(&cfg.Workers, &WorkerExistRule{
			AvailableWorkers: AvailableWorkers,
		}),
	)
}

func (cfg Cfg) FillDefaultWorkers() {
	for k := range AvailableWorkers {
		cfg.Workers = append(cfg.Workers, k)
	}
}

{{if .db}}
type DBCfg struct {
	ConnURL     string `json:"conn_url" yaml:"conn_url"` //The database connection string.
	InitTimeout int    `json:"dbInitTimeout" yaml:"init_timeout"`
	// AutoMigrate if `true` execute db migrate up on start.
	AutoMigrate bool `json:"auto_migrate" yaml:"auto_migrate"`
	WaitForDB   bool `json:"wait_for_db" yaml:"wait_for_db"`
}

func (cfg DBCfg) Validate() error {
	return validation.ValidateStruct(&cfg,
		validation.Field(&cfg.ConnURL, validation.Required),
		validation.Field(&cfg.InitTimeout, validation.Required),
	)
}
{{end}}

func ReadConfig(path string) Cfg {
	rawConfig, err := ioutil.ReadFile(path)
	if err != nil {
		logrus.New().WithError(err).
			WithField("path", path).
			Fatal("unable to read config file")
	}

	config := new(Cfg)
	err = yaml.Unmarshal(rawConfig, config)
	if err != nil {
		logrus.New().WithError(err).
			WithField("raw_config", rawConfig).
			Fatal("unable to unmarshal config file")
	}

	err = config.Validate()
	if err != nil {
		logrus.New().WithError(err).
			Fatal("Invalid configuration")
	}

	_, err = log.Init(log.Config{
		AppName:  config.Log.AppName,
		Level:    config.Log.Level,
		Sentry:   config.Log.Sentry,
		AddTrace: config.Log.AddTrace,
		JSON:     config.Log.JSON,
	})
	if err != nil {
		logrus.New().
			WithError(err).
			Fatal("Unable to init log")
	}
	return *config
}
