package demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * Simulated warm-up. ApplicationRunners run after the web servers start but BEFORE Spring
 * publishes ReadinessState.ACCEPTING_TRAFFIC: /health/liveness is UP, /health/readiness is 503.
 */
@Component
public class WarmUp implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(WarmUp.class);

    @Value("${startup.delay-seconds:30}")
    private int delaySeconds;

    @Override
    public void run(ApplicationArguments args) throws InterruptedException {
        log.info("warming up caches... ({}s)", delaySeconds);
        long t0 = System.nanoTime();
        Thread.sleep(delaySeconds * 1000L);
        log.info("warm-up done after {}s", (System.nanoTime() - t0) / 1_000_000_000);
    }
}
