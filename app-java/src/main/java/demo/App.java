package demo;

import java.util.concurrent.ThreadLocalRandom;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class App {

    public static void main(String[] args) {
        SpringApplication.run(App.class, args);
    }

    /** Holds a Tomcat worker thread for a random time in [minWait, maxWait] ms (waiting, not CPU). */
    @GetMapping("/")
    public String wait(@RequestParam(required = false) String minWait,
                       @RequestParam(required = false) String maxWait) throws InterruptedException {
        int min = parse(minWait);
        int max = Math.max(min, parse(maxWait));
        int n = ThreadLocalRandom.current().nextInt(min, max + 1);
        Thread.sleep(n);
        return "waited " + n + "ms (thread " + Thread.currentThread().getName() + ")\n";
    }

    private static int parse(String s) {
        try {
            return Math.max(0, Math.min(30000, Integer.parseInt(s)));
        } catch (NumberFormatException e) {
            return 0;
        }
    }
}
