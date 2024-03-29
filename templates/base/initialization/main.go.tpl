package initialization

import (
	"fmt"
	"sync"
	"time"

	"github.com/lancer-kit/armory/log"
	"github.com/lancer-kit/armory/tools"
	"github.com/sirupsen/logrus"
	"github.com/urfave/cli"

	"{{.project_name}}/config"
	"{{.project_name}}/dbschema"
)

type initModule string


const flagConfig = "config"
const defaultInitInterval = 5 * time.Second

func Init(c *cli.Context) *config.Cfg {
	var initConfigs = map[initModule]func(*config.Cfg, *logrus.Entry) error{
	    {{if .db}}
		DB:   initDatabase,
		{{end}}
	}

	cfg := config.ReadConfig(c.GlobalString(flagConfig))

	wg := sync.WaitGroup{}
	for module, initializer := range initConfigs {
		var timeout time.Duration
		if module == DB {
			timeout = time.Duration(cfg.DB.InitTimeout) * time.Second
		} else {
			timeout = time.Duration(cfg.ServicesInitTimeout) * time.Second
		}

		wg.Add(1)

		go func(module initModule, initializer func(*config.Cfg, *logrus.Entry) error, timeout time.Duration) {
			defer wg.Done()
			ok := tools.RetryIncrementallyUntil(
				defaultInitInterval,
				timeout,

				func() bool {
					err := initializer(&cfg, log.Default)
					if err != nil {
						log.Default.WithError(err).Error("Can't init " + module)
					}
					return err == nil
				})
			if !ok {
				log.Default.Fatal("Can't init " + module)
			}
		}(module, initializer, timeout)
	}

	wg.Wait()

    {{if .db}}
	if cfg.DB.AutoMigrate {
		count, err := dbschema.Migrate(cfg.DB.ConnURL, "up")
		if err != nil {
			log.Default.WithError(err).Fatal("Migrations failed")
			return &cfg
		}

		log.Default.Info(fmt.Sprintf("Applied %d %s migration", count, "up"))
	}
	{{end}}

	return &cfg
}
